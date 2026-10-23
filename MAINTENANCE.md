# Maintained fork

This fork starts from pock/pock commit `127aac1` (June 2022). The first maintenance pass targets current Xcode and local installation, while preserving the existing widget ABI and macOS 10.15 deployment target.

## Build and test

Requirements: full Xcode selected with `xcode-select`, CocoaPods 1.16.2, Python 3.
Run Xcode's first launch setup if prompted, then:

```sh
pod install --deployment
python3 Tests/run.py
bash scripts/build.sh Release
```

The app is written to `.build/DerivedData/Build/Products/Release/Pock.app`.
Building never terminates running apps or installs to Applications. To install locally, quit Pock and run `bash scripts/install-local.sh`. It stages an ad hoc signed copy, preserves any previous installation as a timestamped backup, installs to `/Applications/Pock.app`, and opens it. A distributed release needs a Developer ID and notarization.

## Maintenance changes

- Remove AppCenter analytics/crash reporting and the missing private Secrets.plist resource.
- Pin PockKit to an immutable commit, fetch over HTTPS, pin direct pods, and commit Podfile.lock.
- Inherit CocoaPods' Swift runtime embedding setting and align dependency deployment targets with macOS 10.15.
- Separate compilation from installation; remove the build phase that killed Pock and copied partial build products.
- Use the production widget catalog for both Debug and Release.
- Bound download request/resource timeouts, ignore unknown content lengths in progress, clamp progress, finish only once, and invalidate download sessions.
- Add local HTTP regression coverage and macOS build CI.

## Remaining work

Pock uses private macOS Touch Bar APIs. Compilation does not establish that every third party widget works on every macOS release. Verify the Dock, media controls, brightness, volume, sleep/wake, and Accessibility permission on the target Mac.

The default widgets remain upstream binary bundles downloaded from pock.app. This pass does not rewrite or audit their implementations. The app's update catalog also still belongs to upstream; fork releases should be installed from this repository until a fork-specific update service is implemented. No new telemetry service is added.
