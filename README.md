# StillWorking

StillWorking is an open-source macOS menu bar app that keeps
an awake Mac from going to sleep due to inactivity for a chosen time, so
background work such as coding-agent runs can continue. The display can follow
its usual sleep settings or stay on during the session.

macOS controls sleep when you close the lid or choose **Apple menu → Sleep**.
The timer counts time spent asleep, and the Mac wakes on its normal schedule
or when you wake it. If the timer expired during sleep, StillWorking shows the
session as finished after wake.

The first milestone is a locally usable app with a countdown, early stop, and a
20% battery cutoff while unplugged. It uses app-owned public macOS power
assertions and runs as a regular user. The project is licensed under [MIT](LICENSE).

## Build and launch locally

Use the full Xcode installation. From the repository root, run:

```sh
xcodebuild -project StillWorking.xcodeproj -scheme StillWorking \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build ARCHS=arm64 test
xcodebuild -project StillWorking.xcodeproj -scheme StillWorking \
  -configuration Release -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build ARCHS=arm64 build
open .build/Build/Products/Release/StillWorking.app
```

You can also open the project in Xcode and choose **Product → Run**. The app
uses ad-hoc signing. It needs neither an Apple developer account nor administrator
privileges. The app deployment target is macOS 13. The build and tests use
Xcode 26.6 on macOS 26.6.2, arm64.

To keep a local copy, use Finder to copy `StillWorking.app` to your user
Applications folder (`~/Applications`) and double-click it there. To remove it,
choose **Quit** or **Stop Timer and Quit** in the panel, then move the app to
the Trash. The app installs no helper and does not change macOS power settings.

Run `pmset -g assertions` to see the app's entries while a session is active.
Check the entries owned by the `StillWorking` process since other apps can
have their own assertions.

## Design and verification

- [Functional specification](https://github.com/vitherain/still-working/issues/1)
- [Design brief and acceptance criteria](docs/design.md)
- [Implementation and verification plan](docs/implementation-plan.md)
- [Glossary](GLOSSARY.md)
- [Platform research and earlier closed-lid investigation](docs/research.md)
