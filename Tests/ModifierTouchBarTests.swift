import AppKit

@main struct ModifierTouchBarTests {
	static func main() {
		precondition(ModifierTouchBarMode(flags: .command) == .appSwitcher)
		precondition(ModifierTouchBarMode(flags: .option) == .controlStrip)
		precondition(ModifierTouchBarMode(flags: [.control, .capsLock]) == .windowLayout)
		precondition(ModifierTouchBarMode(flags: [.command, .shift]) == nil)
		precondition(ModifierTouchBarMode(flags: [.command, .option]) == nil)
		precondition(ModifierTouchBarMode(flags: [.control, .function]) == nil)
		precondition(ModifierTouchBarMode(flags: []) == nil)

		let visible = CGRect(x: 0, y: 25, width: 1440, height: 875)
		let window = CGRect(x: 300, y: 200, width: 800, height: 600)
		precondition(WindowLayout.leftHalf.frame(for: window, in: visible) == CGRect(x: 0, y: 25, width: 720, height: 875))
		precondition(WindowLayout.rightHalf.frame(for: window, in: visible) == CGRect(x: 720, y: 25, width: 720, height: 875))
		precondition(WindowLayout.bottomHalf.frame(for: window, in: visible).maxY == visible.maxY)
		precondition(WindowLayout.maximize.frame(for: window, in: visible) == visible)
		let thirds = [WindowLayout.leftThird, .centerThird, .rightThird].map { $0.frame(for: window, in: visible) }
		precondition(thirds.map(\.width).reduce(0, +) == visible.width && thirds[2].maxX == visible.maxX)
		let centered = WindowLayout.center.frame(for: CGRect(x: 0, y: 0, width: 2000, height: 600), in: visible)
		precondition(centered.width == visible.width && centered.midY.rounded() == visible.midY.rounded())

		let external = CGRect(x: 1440, y: 0, width: 2560, height: 1415)
		let moved = WindowLayout.moved(window, from: visible, to: external)
		precondition(external.contains(moved) && moved.width > window.width)
		precondition(WindowLayout.accessibilityRect(CGRect(x: 0, y: 0, width: 1440, height: 875), primaryHeight: 900).minY == 25)

		var order = ApplicationOrder()
		order.activated(10)
		order.activated(20)
		order.activated(10)
		precondition(order.sorted([30, 20, 10]) == [10, 20, 30])
		precondition(order.sorted([30]) == [30])
		print("PASS modifier detection, window layouts, display moves and app ordering")
	}
}
