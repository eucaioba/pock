import Foundation

// Minimal app services so this harness compiles the real downloader in isolation.
protocol PockError: Error { var description: String { get } }
extension String {
    var localized: String { self }
    func localized(_ arguments: CVarArg...) -> String { self }
}
extension FileManager {
    func createFolderIfNeeded(at path: String) -> Bool {
        do { try createDirectory(atPath: path, withIntermediateDirectories: true); return true }
        catch { return false }
    }
}
enum Roger { static func error(_ error: Error) {} }
enum Updater { static let fullAppVersion = "0.10.0-5" }
let kWidgetsTempPathURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["POCK_TEST_TEMP"]!)

@main
struct DownloaderTests {
    static func main() throws {
        let base = CommandLine.arguments[1]
        var delegates: [() -> Downloader?] = []
        for (path, succeeds) in [("ok", true), ("unknown-length", true), ("missing", false), ("truncated", false)] {
            autoreleasepool {
                let semaphore = DispatchSemaphore(value: 0)
                var count = 0
                var result: URL?
                var failure: DownloaderError?
                let downloader = Downloader(url: URL(string: base + path)!, progress: { progress in
                    precondition(progress.isFinite && (0...1).contains(progress), "Invalid progress")
                }, completion: { location, error in
                    count += 1
                    result = location
                    failure = error
                    semaphore.signal()
                })
                delegates.append({ [weak downloader] in downloader })
                precondition(semaphore.wait(timeout: .now() + 10) == .success, "Download hung: \(path)")
                precondition(count == 1, "Duplicate completion: \(path)")
                if succeeds {
                    precondition(failure == nil && result != nil, "Download failed: \(path)")
                    precondition(try! String(contentsOf: result!, encoding: .utf8) == "widget-data")
                } else {
                    precondition(result == nil && failure != nil, "Expected failure: \(path)")
                }
                print("PASS \(path)")
            }
        }
        // Invalidating the session releases its delegate asynchronously.
        let deadline = Date().addingTimeInterval(5)
        while delegates.contains(where: { $0() != nil }) && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(delegates.allSatisfy { $0() == nil }, "URLSession retained its downloader")
        print("PASS sessions release downloader delegates")
    }
}
