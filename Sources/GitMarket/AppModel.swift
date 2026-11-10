import AppKit
import GitMarketCore
import UserNotifications

enum Activity: Equatable {
    case checking
    case installing
    case failed(String)
}

struct TeamChangePrompt {
    let appID: UUID
    let message: String
}

/// The list of tracked apps and everything that happens to them. Shows stored state at once; checks fill in later.
@MainActor
final class AppModel: ObservableObject {
    private static let intervalKey = "checkIntervalHours"
    private static let defaultIntervalHours = 6
    private static let secondsPerHour: TimeInterval = 3600
    private static let applicationsDirectory = URL(fileURLWithPath: "/Applications")
    private static let schedulerIdentifier = "\(AppIdentity.bundleIdentifier).check"

    @Published private(set) var apps: [TrackedApp] = []
    @Published private(set) var activity: [UUID: Activity] = [:]
    @Published var teamChangePrompt: TeamChangePrompt?
    @Published var errorMessage: String?
    @Published var checkIntervalHours: Int {
        didSet {
            UserDefaults.standard.set(checkIntervalHours, forKey: Self.intervalKey)
            scheduleChecks()
        }
    }

    private let store = TrackedAppStore()
    private let service = MarketService(installer: Installer(installDirectory: AppModel.applicationsDirectory))
    private var scheduler: NSBackgroundActivityScheduler?

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.intervalKey)
        checkIntervalHours = stored > 0 ? stored : Self.defaultIntervalHours
        do {
            apps = try store.load()
        } catch {
            errorMessage = "Could not read the app list: \(ErrorDescription.text(for: error))"
        }
        scheduleChecks()
        requestNotificationPermission()
        Task { await checkAll() }
    }

    var updateCount: Int { apps.filter(\.hasUpdate).count }
    var hosts: [String] { Array(Set(apps.map(\.location.host))).sorted() }

    func preview(_ repositoryText: String, kind: ForgeKind?) async throws -> ReleasePreview {
        try await service.preview(repositoryText: repositoryText, kind: kind)
    }

    func addAndInstall(_ preview: ReleasePreview) {
        let name = preview.location.pathComponents.last ?? preview.location.displayName
        let app = TrackedApp(location: preview.location, displayName: name)
        apps.append(app)
        persist()
        Task { await install(app.id) }
    }

    func remove(_ id: UUID) {
        apps.removeAll { $0.id == id }
        activity[id] = nil
        persist()
    }

    func updateOptions(of id: UUID, includePrereleases: Bool, assetNamePattern: String?) {
        mutate(id) {
            $0.includePrereleases = includePrereleases
            $0.assetNamePattern = assetNamePattern
        }
    }

    func checkAll() async {
        let alreadyUpdatable = Set(apps.filter(\.hasUpdate).map(\.id))
        await withTaskGroup(of: Void.self) { group in
            for app in apps {
                group.addTask { await self.check(app.id) }
            }
        }
        notifyAboutNewUpdates(excluding: alreadyUpdatable)
    }

    func installAllUpdates() async {
        for app in apps where app.hasUpdate {
            await install(app.id)
        }
    }

    func install(_ id: UUID, allowSigningTeamChange: Bool = false) async {
        guard let app = apps.first(where: { $0.id == id }) else { return }
        activity[id] = .installing
        do {
            let installed = try await service.install(app, allowSigningTeamChange: allowSigningTeamChange)
            mutate(id) {
                $0.installedTag = installed.installedTag
                $0.latestKnownTag = installed.latestKnownTag
                $0.installedBundlePath = installed.installedBundlePath
                $0.installedSignature = installed.installedSignature
                $0.lastCheckedAt = installed.lastCheckedAt
            }
            activity[id] = nil
        } catch InstallError.signingTeamChanged(let previousTeam, let newSignature) {
            activity[id] = nil
            teamChangePrompt = TeamChangePrompt(appID: id, message: Self.teamChangeMessage(app.displayName, previousTeam, newSignature))
        } catch {
            activity[id] = .failed(ErrorDescription.text(for: error))
        }
    }

    private func check(_ id: UUID) async {
        guard let app = apps.first(where: { $0.id == id }) else { return }
        activity[id] = .checking
        do {
            let checked = try await service.check(app)
            mutate(id) {
                $0.latestKnownTag = checked.latestKnownTag
                $0.lastCheckedAt = checked.lastCheckedAt
            }
            activity[id] = nil
        } catch {
            activity[id] = .failed(ErrorDescription.text(for: error))
        }
    }

    private func mutate(_ id: UUID, _ change: (inout TrackedApp) -> Void) {
        guard let index = apps.firstIndex(where: { $0.id == id }) else { return }
        change(&apps[index])
        persist()
    }

    private func persist() {
        do {
            try store.save(apps)
        } catch {
            errorMessage = "Could not save the app list: \(ErrorDescription.text(for: error))"
        }
    }

    private static func teamChangeMessage(_ name: String, _ previousTeam: String, _ new: SignatureInfo) -> String {
        let newDescription: String
        switch new {
        case .team(let team): newDescription = "developer team \(team)"
        case .adHoc: newDescription = "no developer identity (ad-hoc)"
        case .unsigned: newDescription = "no signature"
        }
        return "The installed \(name) is signed by developer team \(previousTeam), but this update is signed with \(newDescription). "
            + "That can mean the repository was taken over. Install only if you expect the change."
    }

    private func scheduleChecks() {
        scheduler?.invalidate()
        let scheduler = NSBackgroundActivityScheduler(identifier: Self.schedulerIdentifier)
        scheduler.interval = TimeInterval(checkIntervalHours) * Self.secondsPerHour
        scheduler.repeats = true
        scheduler.qualityOfService = .utility
        scheduler.schedule { [weak self] completion in
            Task { @MainActor in
                await self?.checkAll()
                completion(.finished)
            }
        }
        self.scheduler = scheduler
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func notifyAboutNewUpdates(excluding alreadyUpdatable: Set<UUID>) {
        let fresh = apps.filter { $0.hasUpdate && !alreadyUpdatable.contains($0.id) }
        guard !fresh.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Updates available"
        content.body = fresh.map(\.displayName).joined(separator: ", ")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
