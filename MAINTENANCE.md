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
Building never terminates running apps or installs to Applications. To install locally, quit Pock and run `bash scripts/install-local.sh`. It stages an ad hoc signed copy, preserves any previous installation as a timestamped backup, installs to `/Applications/Pock.app`, installs the matching bundled widgets, and opens it. Existing widget bundles with matching filenames are preserved in the staging directory before replacement. A distributed release needs a Developer ID and notarization.

## Maintenance changes

- Remove AppCenter analytics/crash reporting and the missing private Secrets.plist resource.
- Pin PockKit to an immutable commit, fetch over HTTPS, pin direct pods, and commit Podfile.lock.
- Inherit CocoaPods' Swift runtime embedding setting and align dependency deployment targets with macOS 10.15.
- Separate compilation from installation; remove the build phase that killed Pock and copied partial build products.
- Restore mouse scrolling forwarding using the protocol actually exposed by the pinned PockKit.
- Vendor the six MIT-licensed default widget sources, build them in the shared workspace, and package them with the host. Default installation works offline and avoids incompatible historical Swift runtime symbols.
- Keep locally rebuilt default widgets out of upstream binary update suggestions.
- Extract archives in the temporary widgets directory, including bundled archives, without writing into the signed app.
- Guard missing cursor locations and backing views when dismissing the empty Touch Bar during customization; add a regression harness for repeated dismissal.
- Preserve dynamic loader diagnostics for widgets that cannot load.
- Bound download request/resource timeouts, ignore unknown content lengths in progress, clamp progress, finish only once, and invalidate download sessions.
- Add local HTTP regression coverage and macOS build CI.

## Remaining work

Pock uses private macOS Touch Bar APIs. Compilation does not establish that every third party widget works on every macOS release. Verify the Dock, media controls, brightness, volume, sleep/wake, and Accessibility permission on the target Mac.

The default widgets are compiled from the upstream sources imported at the commits documented in Vendor/Widgets/README.md. Their existing private macOS APIs and weather service still need behavioral validation; recompilation does not modernize every service. The app's core update catalog and third party widget catalog still belong to upstream; fork releases should be installed from this repository until a fork-specific update service is implemented. Bundled defaults are excluded from upstream update suggestions. No new telemetry service is added.
