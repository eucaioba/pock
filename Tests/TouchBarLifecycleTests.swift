import AppKit

// Model the system's absent Touch Bar view during palette transition. The
// controller and its PockKit dismissal path are the production implementations.
enum NSFunctionRow {
    static func _topLevelViews() -> Any? { nil }
}
enum Roger { static func debug(_ message: String) {} }
extension String { var localized: String { self } }
func async(after delay: Double, _ block: @escaping () -> Void) {}
final class AppController {
    static let shared = AppController()
    func openPockCustomizationPalette() {}
    func reInstallDefaultWidgets() {}
}

@main
struct TouchBarLifecycleTests {
    static func main() {
        let controller = EmptyTouchBarController()
        // Customization dismisses the empty bar after its backing view is gone.
        controller.dismiss()
        controller.dismiss()
        controller.updateCursorLocation(nil)
        controller.updateCursorLocation(NSPoint(x: 12, y: 12))
        print("PASS empty Touch Bar dismissal without a backing view")
    }
}
