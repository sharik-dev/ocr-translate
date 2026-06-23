fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots via the UITest target

### ios create_app

```sh
[bundle exec] fastlane ios create_app
```

Register the bundle id + create the app on App Store Connect

### ios ensure_version

```sh
[bundle exec] fastlane ios ensure_version
```

Create the editable 1.0 version + review detail if missing (run once before metadata)

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Push App Store listing text + marketing screenshots (draft, no submit)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build a signed release and upload it to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
