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


## App Controls

`App Controls` is a built-in Touch Bar item (not a widget bundle) whose buttons follow the frontmost app: browsers, terminals, VS Code/Cursor, Xcode, Finder, Zoom and Teams ship as profiles in `AppProfile.builtIn`. Buttons post keyboard shortcuts to the app with `CGEvent.postToPid`, which needs Accessibility trust. Characters are mapped to key codes through the current keyboard layout (`UCKeyTranslate`), so shortcuts such as `cmd+[` work on ABNT2 and other non-US layouts.

Profiles can be disabled in Preferences. `~/Library/Application Support/Pock/AppProfiles.json` holds custom profiles (`id`, `name`, `apps` with optional trailing `*` prefix match, `actions` with `title`, optional SF Symbol `symbol`, and `shortcut` like `cmd+shift+]`); they are matched before built-ins and load when Pock reloads. Existing saved layouts get the item inserted once after the Dock. `scripts/test-modifier-bars.sh` also covers shortcut parsing and profile matching.

## Default widget fixes (review)

Weather uses Open-Meteo because weather.navalia.app stopped responding. The Dock reads all notification badges in one Accessibility pass. Badges and window previews depend on Accessibility, which ad hoc builds lost on every reinstall before the stable signing identity. The legacy Do Not Disturb item is hidden on macOS 12+.

## Native app Touch Bars

Apps listed under "Use the app's own Touch Bar" (Safari by default) make Pock minimize its system modal bar while they are frontmost, so the app's own Touch Bar (Safari tabs, media scrubbers) shows. Pock comes back on the next app switch; double `⌃` restores it for the current app. Modifier bars present directly over the app's Touch Bar in that state.

Mouse support (mirroring the cursor on the Touch Bar when it nears the bottom screen edge) is now off by default, because the 10 pt tracking strip overlaps the Dock.


## Built-in widgets

Default widgets are being rewritten as items compiled into Pock (`Pock/UI/TouchBar/BuiltInWidgets`), sharing `SystemControls` with the modifier bars instead of each bundle carrying its own helpers. Third-party `.pock` bundles still load as before. `BuiltInWidgets.replacements` swaps a retired bundle's identifier for its built-in item in the saved layout, keeping its position, and `retiredWidgetBundles` are deleted from the widgets folder on launch.

`Controls` replaces Control Center (and its `Defaults` pod): brightness (DisplayServices) and volume (CoreAudio) with live values and a full-width `NSSliderTouchBarItem` on tap, mute, lock screen (`SACLockScreenImmediate`), display sleep, screen saver, and Focus through a user Shortcut (`shortcuts run`), since Focus has no public toggle API. Buttons are chosen in Preferences. `scripts/build.sh` now clears stale archives so retired widgets are not repackaged.

`Status` replaces the Status widget and reads the same preference keys, so existing choices carry over. Battery updates from `IOPSNotificationCreateRunLoopSource` instead of a 1 s poll, the clock fires on minute (or second) boundaries, the input source follows the TIS change notification and cycles on tap, and Wi-Fi signal comes from CoreWLAN RSSI (no Location permission; the SSID is not shown). The retired widget never showed its clock: assigning `Preferences[...]` straight to `DateFormatter.dateFormat` (`String!`) inferred an optional type and returned nil instead of the default format.


`Dock` replaces the Dock widget (3,100 lines) with a scrubber of the apps pinned in the system Dock's own plist plus any other running app, running indicators, a highlight on the frontmost app, notification badges, the Dock's folders and the Trash. Display options keep the widget's preference keys. Badges are read from the Dock process through Accessibility in one pass off the main thread every 10 s. Tapping an app uses `NSWorkspace.openApplication`, which matches a Dock click (unhide, reopen a window, or launch).

Dropped on purpose: window previews (`CGWindowListCreateImage` is obsolete and needs Screen Recording), the in-bar Finder browser, hiding the system Dock through `CoreDock`, and drag and drop onto icons. Folders open in Finder. `scripts/test-modifier-bars.sh` covers plist parsing, ordering and badge text.

`Weather` replaces the Weather widget and the 560-line preference pane built on a 1 MB city CSV. Conditions come from Open-Meteo (no key); the city is searched by name through Open-Meteo geocoding in Preferences, and until one is chosen the city named by the Mac's time zone is used, so it works without setup and without Location permission. Tapping the item opens a bar with feels-like, today's range, rain chance and the next six hours. Preference keys are the widget's (`city_name`, `lat`, `lng`, `units`, `show_description`). Symbols replace the bundled PNG set.

Customizing the Touch Bar (Preferences menu > Customize Pock) must not hand the live built-in items to the palette's `NSTouchBar`: AppKit items belong to one bar, so `AppController` builds a separate palette item with a dark-appearance snapshot (`BuiltInWidgets.previewView`).
