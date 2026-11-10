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
    private static let ownRepositoryURL = "https://github.com/SchotjeChrisman/git-market"
    private static let relaunchDelaySeconds = 2
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
        trackItself()
        scheduleChecks()
        requestNotificationPermission()
        Task { await checkAll() }
    }

    var updateCount: Int { apps.filter { $0.hasUpdate || $0.isInstallable }.count }
    var hosts: [String] { Array(Set(apps.map(\.location.host))).sorted() }

    func locate(_ repositoryText: String, kind: ForgeKind?) async throws -> ForgeLocation {
        try await service.locate(repositoryText: repositoryText, kind: kind)
    }

    func preview(_ repositoryText: String, kind: ForgeKind?, includePrereleases: Bool) async throws -> ReleasePreview {
        try await service.preview(repositoryText: repositoryText, kind: kind, includePrereleases: includePrereleases)
    }

    func addAndInstall(_ preview: ReleasePreview, includePrereleases: Bool) {
        let id = track(preview.location, includePrereleases: includePrereleases)
        Task { await install(id) }
    }

    /// Tracks a repository that has no installable release yet; the next check offers the install.
    func addWithoutInstalling(_ location: ForgeLocation, includePrereleases: Bool) {
        let id = track(location, includePrereleases: includePrereleases)
        Task { await check(id) }
    }

    private func track(_ location: ForgeLocation, includePrereleases: Bool) -> UUID {
        let name = location.pathComponents.last ?? location.displayName
        let app = TrackedApp(location: location, displayName: name, includePrereleases: includePrereleases)
        apps.append(app)
        persist()
        return app.id
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
        let alreadyUpdatable = Set(apps.filter { $0.hasUpdate || $0.isInstallable }.map(\.id))
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
                $0.installedAssetName = installed.installedAssetName
                $0.installedPublishedAt = installed.installedPublishedAt
                $0.latestKnownPublishedAt = installed.latestKnownPublishedAt
                $0.latestKnownTag = installed.latestKnownTag
                $0.latestKnownAssetName = installed.latestKnownAssetName
                $0.installedBundlePath = installed.installedBundlePath
                $0.installedSignature = installed.installedSignature
                $0.lastCheckedAt = installed.lastCheckedAt
            }
            activity[id] = nil
            if isItself(app), let path = installed.installedBundlePath { relaunch(bundlePath: path) }
        } catch InstallError.signingTeamChanged(let previousTeam, let newSignature) {
            activity[id] = nil
            teamChangePrompt = TeamChangePrompt(appID: id, message: Self.teamChangeMessage(app.displayName, previousTeam, newSignature))
        } catch {
            activity[id] = .failed(ErrorDescription.text(for: error))
        }
    }

    /// Git Market updates itself like any other tracked app. Skipped when run outside a .app bundle (swift run).
    private func trackItself() {
        guard Bundle.main.bundleURL.pathExtension == "app",
              let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        do {
            let location = try ForgeLocation(parsing: Self.ownRepositoryURL)
            guard !apps.contains(where: { $0.location == location }) else { return }
            var app = TrackedApp(location: location, displayName: AppIdentity.displayName)
            app.installedTag = "v\(version)"
            app.installedBundlePath = Bundle.main.bundlePath
            apps.append(app)
            persist()
        } catch {
            errorMessage = "Could not track Git Market itself: \(ErrorDescription.text(for: error))"
        }
    }

    private func isItself(_ app: TrackedApp) -> Bool {
        app.location.host == "github.com" && app.location.pathComponents == ["SchotjeChrisman", "git-market"]
    }

    private func relaunch(bundlePath: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "sleep \(Self.relaunchDelaySeconds); /usr/bin/open \"$0\"", bundlePath]
        do {
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            errorMessage = "Updated, but could not restart: \(ErrorDescription.text(for: error))"
        }
    }

    private func check(_ id: UUID) async {
        guard let app = apps.first(where: { $0.id == id }) else { return }
        activity[id] = .checking
        do {
            let checked = try await service.check(app)
            mutate(id) {
                $0.latestKnownTag = checked.latestKnownTag
                $0.latestKnownAssetName = checked.latestKnownAssetName
                $0.latestKnownPublishedAt = checked.latestKnownPublishedAt
                $0.installedBundleVersion = checked.installedBundlePath.flatMap(InstalledBundleVersion.read(atPath:))
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
        let fresh = apps.filter { ($0.hasUpdate || $0.isInstallable) && !alreadyUpdatable.contains($0.id) }
        guard !fresh.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "Updates available"
        content.body = fresh.map(\.displayName).joined(separator: ", ")
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
