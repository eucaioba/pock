# Maintained fork

This fork starts from pock/pock commit `127aac1` (June 2022). The first maintenance pass targets current Xcode and local installation, while preserving the existing widget ABI and macOS 10.15 deployment target.

## Build and test

Requirements: full Xcode selected with `xcode-select`, Ruby 3.4.4, Bundler, Python 3. CocoaPods and JSON serialization versions are locked in Gemfile.lock.
Run Xcode's first launch setup if prompted, then:

```sh
bundle install
bundle exec pod install --deployment
python3 Tests/run.py
bash scripts/build.sh Release
bash scripts/test-widgets.sh Release
bash scripts/test-touchbar-lifecycle.sh
```

The app is written to `.build/DerivedData/Build/Products/Release/Pock.app`.
Building never terminates running apps or installs to Applications. To install locally, quit Pock and run `bash scripts/install-local.sh`. Run `bash scripts/create-local-signing-identity.sh` once first: it adds a self-signed "Pock Local Signing" certificate to the login keychain, and installs signed with it keep a stable designated requirement, so Accessibility and Automation grants survive rebuilds. Without it, installs fall back to ad hoc signing, whose cdhash-based identity invalidates those grants on every build. It stages an ad hoc signed copy, preserves any previous installation as a timestamped backup, installs to `/Applications/Pock.app`, installs the matching bundled widgets, and opens it. Existing widget bundles with matching filenames are preserved in the staging directory before replacement. A distributed release needs a Developer ID and notarization.

## Maintenance changes

- Remove AppCenter analytics/crash reporting and the missing private Secrets.plist resource.
- Pin PockKit to an immutable commit, fetch over HTTPS, pin direct pods, and commit Podfile.lock.
- Inherit CocoaPods' Swift runtime embedding setting and align dependency deployment targets with macOS 10.15.
- Separate compilation from installation; remove the build phase that killed Pock and copied partial build products.
- Restore mouse scrolling forwarding using the protocol actually exposed by the pinned PockKit.
- Vendor the six MIT-licensed default widget sources, build them in the shared workspace, and package them with the host. Default installation works offline and avoids incompatible historical Swift runtime symbols.
- Keep locally rebuilt default widgets out of upstream binary update suggestions.
- Extract archives in the temporary widgets directory, including bundled archives, without writing into the signed app.
- Provide a deterministic first-run widget layout on both the main Touch Bar and its customization palette, preserving saved user customization.
- Guard missing cursor locations and backing views when dismissing the empty Touch Bar during customization; add a regression harness for repeated dismissal.
- Preserve dynamic loader diagnostics for widgets that cannot load.
- Bound download request/resource timeouts, ignore unknown content lengths in progress, clamp progress, finish only once, and invalidate download sessions.
- Add local HTTP regression coverage and macOS build CI.

## Remaining work

Pock uses private macOS Touch Bar APIs. Compilation does not establish that every third party widget works on every macOS release. Verify the Dock, media controls, brightness, volume, sleep/wake, and Accessibility permission on the target Mac.

The default widgets are compiled from the upstream sources imported at the commits documented in Vendor/Widgets/README.md. Their existing private macOS APIs and weather service still need behavioral validation; recompilation does not modernize every service. The app's core update catalog and third party widget catalog still belong to upstream; fork releases should be installed from this repository until a fork-specific update service is implemented. Bundled defaults are excluded from upstream update suggestions. No new telemetry service is added.


## Now Playing 0.11.0

The media widget uses explicit application automation for Spotify, Music, and Safari YouTube tabs. It does not use a scripting interpreter to access restricted global MediaRemote metadata. The host declares its Apple Events usage and macOS prompts for Automation permission. Safari additionally requires “Allow JavaScript from Apple Events”; the user must authorize enabling that option. Safari scripts check an HTTPS YouTube hostname and the exact tab URL before controlling playback.

Hold the media widget to open a Touch Bar with playback controls and a seek slider. Source pinning lives only in the widget preferences; the Touch Bar always follows the selected source. Safari's previous/next controls seek backward/forward 10 seconds. Source pinning prevents other apps from receiving commands. Automatic mode prefers playing sessions, the foreground player, then the current session. Polling is serialized off the main thread, skips overlap, times out, and resumes after wake. Pending seeks are cancelled when changing source. Artwork comes from the player/page rather than an iTunes search.

Run `bash scripts/test-media.sh` for source-selection and scripted Spotify/Safari fixtures, including YouTube host isolation, tab revalidation, seeking bounds, and denied permission handling. Live Automation permissions and physical Touch Bar behavior require on-device validation.

## Modifier Touch Bars

Holding `⌘`, `⌥` or `⌃` alone for 0.45 s pushes a dedicated Touch Bar on top of Pock; releasing the key, adding another modifier, or typing any key closes it. Input event counters (`CGEventSource.counterForEventType`) cancel the bar when the modifier was used for a shortcut or click, so no keyboard monitoring permission is needed beyond the existing `flagsChanged` monitor. Double `⌃` still toggles the system Touch Bar.

- `⌘`: running regular apps in most-recently-used order; tapping opens the app the way the Dock does.
- `⌥`: built-in display brightness (DisplayServices), output volume and mute (CoreAudio), Mission Control, Apps/Launchpad, and display sleep. Values are set directly because posting media keys while `⌥` is held opens System Settings.
- `⌃`: halves, thirds, center, fill, and next display for the frontmost window through the Accessibility API. Without Accessibility trust the bar offers the system prompt.

Each bar can be disabled in Pock Preferences. Run `bash scripts/test-modifier-bars.sh` for modifier detection, window geometry, and app ordering.

