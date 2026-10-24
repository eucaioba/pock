import AppKit

@main struct AppProfileTests {
	static func main() throws {
		precondition(KeyboardShortcut("cmd+[") == KeyboardShortcut("Command+["))
		precondition(KeyboardShortcut("cmd+shift+]")?.modifiers == [.command, .shift])
		precondition(KeyboardShortcut("ctrl+tab")?.key == .code(0x30))
		precondition(KeyboardShortcut("cmd+.")?.key == .character("."))
		precondition(KeyboardShortcut("cmd++")?.key == .character("+"))
		precondition(KeyboardShortcut("ctrl+shift+-")?.key == .character("-"))
		precondition(KeyboardShortcut("hyper+x") == nil)
		precondition(KeyboardShortcut("cmd+") == nil)
		precondition(KeyboardShortcut("cmd+enterx") == nil)
		for profile in AppProfile.builtIn {
			for action in profile.actions {
				precondition(action.keyboardShortcut != nil, "\(profile.id): \(action.shortcut)")
			}
		}
		precondition(Set(AppProfile.builtIn.map(\.id)).count == AppProfile.builtIn.count)

		let builtIn = AppProfile.builtIn
		precondition(AppProfile.profile(for: "com.apple.Safari", in: builtIn, disabled: [])?.id == "browser")
		precondition(AppProfile.profile(for: "com.google.Chrome.canary", in: builtIn, disabled: [])?.id == "browser")
		precondition(AppProfile.profile(for: "com.anysphere.sand", in: builtIn, disabled: [])?.id == "code")
		precondition(AppProfile.profile(for: "com.apple.Safari", in: builtIn, disabled: ["browser"]) == nil)
		precondition(AppProfile.profile(for: "net.whatsapp.WhatsApp", in: builtIn, disabled: []) == nil)
		precondition(AppProfile.profile(for: nil, in: builtIn, disabled: []) == nil)

		let json = #"[{"id":"safari-custom","name":"Safari","apps":["com.apple.Safari"],"actions":[{"title":"Tabs","shortcut":"cmd+shift+\\"}]}]"#
		let custom = try JSONDecoder().decode([AppProfile].self, from: Data(json.utf8))
		precondition(custom[0].actions[0].symbol == nil && custom[0].actions[0].keyboardShortcut != nil)
		precondition(AppProfile.profile(for: "com.apple.Safari", in: custom + builtIn, disabled: [])?.id == "safari-custom")
		print("PASS shortcut parsing, built-in profiles, matching, overrides and custom JSON")
	}
}
