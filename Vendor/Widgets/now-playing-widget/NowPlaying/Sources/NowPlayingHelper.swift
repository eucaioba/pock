import AppKit

extension Notification.Name {
    static let pockMediaDidUpdate = Notification.Name("PockMediaDidUpdate")
}

final class NowPlayingHelper: NSObject {
    private(set) var currentNowPlayingItem = NowPlayingItem()
    private(set) var snapshot: MediaSnapshot?
    private(set) var status = "Aguardando mídia"
    weak var view: NowPlayingView?
    private let backend = AutomationMediaBackend()
    private let worker = DispatchQueue(label: "app.pock.media-automation", qos: .utility)
    private var timer: Timer?
    private var polling = false
    private var artworkTask: URLSessionDataTask?
    private var artworkIdentity: String?
    private var pendingSeek: DispatchWorkItem?
    private let commandLock = NSLock()
    private var commandGeneration = 0
    private var lastPreference: MediaSource?

    private func generation() -> Int {
        commandLock.lock(); defer { commandLock.unlock() }
        return commandGeneration
    }
    private func invalidateCommands() {
        commandLock.lock(); commandGeneration += 1; commandLock.unlock()
        pendingSeek?.cancel()
    }

    var source: MediaSource {
        MediaSource(rawValue: Preferences[.preferredMediaSource] as String) ?? .automatic
    }

    init(forView: NowPlayingView) {
        view = forView
        super.init()
        timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: Notification.Name(didChangeNowPlayingWidgetStyle), object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        refresh()
    }

    @objc func refresh() {
        guard !polling else { return }
        polling = true
        let preference = source
        if lastPreference != preference { invalidateCommands(); lastPreference = preference }
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        worker.async { [weak self] in
            guard let self = self else { return }
            let result = Result { try self.backend.execute(source: preference) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.polling = false
                guard self.source == preference else { self.refresh(); return }
                switch result {
                case .success(let poll):
                    let selected = MediaSelection.select(poll.sessions, preference: preference, current: self.snapshot, frontmost: frontmost)
                    self.snapshot = selected
                    let failures = poll.errors.filter { preference == .automatic || $0.source == preference }
                    if selected != nil { self.status = "" }
                    else if failures.contains(where: { $0.code == -1743 }) { self.status = "Autorize o Pock em Automação" }
                    else if failures.contains(where: { $0.source == .safari }) { self.status = "Safari: habilite JavaScript de Eventos Apple" }
                    else { self.status = "Nenhuma mídia em reprodução" }
                case .failure(let error):
                    self.snapshot = nil
                    self.status = error.localizedDescription
                }
                self.publish()
            }
        }
    }

    private func publish() {
        let item = currentNowPlayingItem
        let active = snapshot?.source ?? source
        let identifier = active.bundleIdentifier
        item.client = NowPlayingItem.Client(bundleIdentifier: identifier, parentApplicationBundleIdentifier: nil,
                                             displayName: active == .automatic ? "Now Playing" : active.title,
                                             icon: identifier.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }.map { NSWorkspace.shared.icon(forFile: $0.path) })
        item.title = snapshot?.title ?? status
        item.artist = snapshot.map { $0.artist.isEmpty ? $0.source.title : "\($0.source.title) · \($0.artist)" }
        item.album = snapshot?.album
        item.isPlaying = snapshot?.playing ?? false
        updateArtwork()
        view?.updateContentViews()
        NotificationCenter.default.post(name: .pockMediaDidUpdate, object: self)
    }

    private func updateArtwork() {
        let identity = snapshot?.identity
        let show: Bool = Preferences[.showMediaArtwork]
        guard show, let snapshot = snapshot, let raw = snapshot.artwork, let url = URL(string: raw), url.scheme == "https" else {
            artworkTask?.cancel()
            artworkIdentity = nil
            currentNowPlayingItem.artwork = nil
            return
        }
        guard identity != artworkIdentity else { return }
        artworkTask?.cancel()
        artworkIdentity = identity
        currentNowPlayingItem.artwork = nil
        artworkTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data = data, data.count < 5_000_000,
                  let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else { return }
            DispatchQueue.main.async {
                guard let self = self, self.snapshot?.identity == identity,
                      (Preferences[.showMediaArtwork] as Bool) else { return }
                self.currentNowPlayingItem.artwork = NSImage(data: data)
                self.view?.updateContentViews()
            }
        }
        artworkTask?.resume()
    }

    private func command(_ action: String, position: Double? = nil) {
        guard let snapshot = snapshot else { return }
        let token = generation()
        worker.async { [weak self] in
            guard let self = self, self.generation() == token else { return }
            let result = try? self.backend.execute(source: snapshot.source, action: action, key: snapshot.key, position: position)
            DispatchQueue.main.async {
                if let failure = result?.errors.first { self.status = failure.message }
                self.refresh()
            }
        }
    }
    func togglePlayingState() { command("toggle") }
    func skipToNextTrack() { command("next") }
    func skipToPreviousTrack() { command("previous") }
    func seek(to position: Double) {
        guard let snapshot = snapshot, snapshot.duration > 0 else { return }
        let target = MediaSnapshot.clamped(position, duration: snapshot.duration)
        pendingSeek?.cancel()
        let identity = snapshot.identity
        let token = generation()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.snapshot?.identity == identity, self.generation() == token else { return }
            self.command("seek", position: target)
        }
        pendingSeek = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
    deinit {
        timer?.invalidate()
        pendingSeek?.cancel()
        artworkTask?.cancel()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

extension NSWorkspace {
    func applicationName(for identifier: String) -> String? {
        urlForApplication(withBundleIdentifier: identifier)?.deletingPathExtension().lastPathComponent
    }
    func applicationIcon(for identifier: String?, fallbackFileType: String? = nil) -> NSImage? {
        guard let identifier = identifier, let url = urlForApplication(withBundleIdentifier: identifier) else {
            return NSImage(named: NSImage.touchBarPlayTemplateName)
        }
        return icon(forFile: url.path)
    }
}
