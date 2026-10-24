import Foundation

/// One serialized worker handles application automation; no work runs on the UI
/// thread. The system attributes subprocess Apple Events to the containing app.
final class AutomationMediaBackend {
    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var storage = Data()
        func set(_ data: Data) { lock.lock(); storage = data; lock.unlock() }
        func get() -> Data { lock.lock(); defer { lock.unlock() }; return storage }
    }
    func execute(source: MediaSource, action: String? = nil, key: String? = nil,
                 position: Double? = nil) throws -> MediaPoll {
        guard let script = Bundle(for: Self.self).url(forResource: "MediaSession", withExtension: "js") else {
            throw NSError(domain: "Pock.Media", code: 1, userInfo: [NSLocalizedDescriptionKey: "Script de mídia ausente"])
        }
        var request: [String: Any] = ["source": source.rawValue]
        request["action"] = action
        request["key"] = key
        request["position"] = position
        let data = try JSONSerialization.data(withJSONObject: request)
        let task = Process()
        let output = Pipe(), errors = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-l", "JavaScript", script.path, String(decoding: data, as: UTF8.self)]
        task.standardOutput = output
        task.standardError = errors
        let finished = DispatchSemaphore(value: 0)
        task.terminationHandler = { _ in finished.signal() }
        try task.run()
        // Drain concurrently so multiple sessions cannot fill the pipe and stall.
        let result = OutputBuffer()
        let drained = DispatchGroup()
        drained.enter()
        DispatchQueue.global().async {
            result.set(output.fileHandleForReading.readDataToEndOfFile())
            drained.leave()
        }
        guard finished.wait(timeout: .now() + 12) == .success else {
            task.terminate()
            throw NSError(domain: "Pock.Media", code: 2, userInfo: [NSLocalizedDescriptionKey: "Aguardando autorização de Automação"])
        }
        drained.wait()
        guard task.terminationStatus == 0 else {
            throw NSError(domain: "Pock.Media", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Não foi possível consultar o player"])
        }
        return try JSONDecoder().decode(MediaPoll.self, from: result.get())
    }
}
