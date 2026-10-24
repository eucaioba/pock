import AppKit
import PockKit

final class NowPlayingControlsController: PKTouchBarController {
    private var helper: NowPlayingHelper?
    private var titleLabel: NSTextField?
    private var previousButton: NSButton?
    private var playButton: NSButton?
    private var nextButton: NSButton?
    private var slider: NSSlider?
    private var timeLabel: NSTextField?
    private var lastSeek = Date.distantPast

    required init() { super.init() }
    required init?(coder: NSCoder) { super.init(coder: coder) }
    convenience init(helper: NowPlayingHelper) {
        self.init()
        self.helper = helper
        NotificationCenter.default.addObserver(self, selector: #selector(update), name: .pockMediaDidUpdate, object: helper)
    }

    override func makeTouchBar() -> NSTouchBar? {
        let bar = NSTouchBar()
        var items: [NSTouchBarItem] = []
        func add(_ name: String, view: NSView) {
            let item = NSCustomTouchBarItem(identifier: NSTouchBarItem.Identifier("Pock.Media." + name))
            item.view = view
            items.append(item)
        }
        let back = NSButton(title: "Voltar", target: self, action: #selector(close))
        back.setAccessibilityLabel("Voltar ao Pock")
        add("Back", view: back)
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 11)
        title.lineBreakMode = .byTruncatingTail
        title.widthAnchor.constraint(equalToConstant: 220).isActive = true
        titleLabel = title
        add("Title", view: title)
        let previous = NSButton(title: "◀", target: self, action: #selector(previous))
        let play = NSButton(title: "▶", target: self, action: #selector(toggle))
        let next = NSButton(title: "▶▶", target: self, action: #selector(next))
        previousButton = previous; playButton = play; nextButton = next
        let transport = NSStackView(views: [previous, play, next])
        transport.orientation = .horizontal
        transport.spacing = 4
        add("Transport", view: transport)
        let position = NSSlider(value: 0, minValue: 0, maxValue: 1, target: self, action: #selector(seek))
        position.isContinuous = true
        position.widthAnchor.constraint(equalToConstant: 200).isActive = true
        position.setAccessibilityLabel("Posição da reprodução")
        slider = position
        let time = NSTextField(labelWithString: "0:00")
        time.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        time.widthAnchor.constraint(equalToConstant: 43).isActive = true
        timeLabel = time
        let progress = NSStackView(views: [position, time])
        progress.spacing = 4
        add("Progress", view: progress)
        bar.templateItems = Set(items)
        bar.defaultItemIdentifiers = items.map(\.identifier)
        update()
        return bar
    }

    @objc private func update() {
        guard let helper = helper else { return }
        let snapshot = helper.snapshot
        titleLabel?.stringValue = snapshot?.title ?? helper.status
        titleLabel?.toolTip = snapshot.map { "\($0.source.title) · \($0.artist)" } ?? helper.status
        playButton?.title = snapshot?.playing == true ? "Ⅱ" : "▶"
        let video = snapshot?.source == .safari
        previousButton?.title = video ? "−10s" : "◀◀"
        nextButton?.title = video ? "+10s" : "▶▶"
        previousButton?.setAccessibilityLabel(video ? "Voltar 10 segundos" : "Faixa anterior")
        nextButton?.setAccessibilityLabel(video ? "Avançar 10 segundos" : "Próxima faixa")
        playButton?.setAccessibilityLabel(snapshot?.playing == true ? "Pausar" : "Reproduzir")
        [previousButton, playButton, nextButton].forEach { $0?.isEnabled = snapshot != nil }
        slider?.isEnabled = (snapshot?.duration ?? 0) > 0
        if Date().timeIntervalSince(lastSeek) > 1.5 {
            slider?.maxValue = max(1, snapshot?.duration ?? 0)
            slider?.doubleValue = snapshot?.displayPosition ?? 0
        }
        let position = Int(snapshot?.displayPosition ?? 0)
        timeLabel?.stringValue = String(format: "%d:%02d", position / 60, position % 60)
    }
    @objc private func close() { dismiss() }
    @objc private func previous() { helper?.skipToPreviousTrack() }
    @objc private func toggle() { helper?.togglePlayingState() }
    @objc private func next() { helper?.skipToNextTrack() }
    @objc private func seek() {
        lastSeek = Date()
        helper?.seek(to: slider?.doubleValue ?? 0)
    }
    deinit { NotificationCenter.default.removeObserver(self) }
}
