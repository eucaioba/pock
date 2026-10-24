import Foundation

// Linked to the same PockKit as the host. Loading must resolve every symbol and
// expose a principal class; a successful xcodebuild alone cannot verify this.
for argument in CommandLine.arguments.dropFirst() {
    let bundle = Bundle(url: URL(fileURLWithPath: argument))!
    try bundle.loadAndReturnError()
    precondition(bundle.principalClass != nil, "Missing widget principal class: \(argument)")
    print("PASS load \(bundle.bundleURL.lastPathComponent)")
}
