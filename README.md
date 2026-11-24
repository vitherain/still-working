# StillWorking

StillWorking is an open-source macOS menu bar app that keeps
an awake Mac from going to sleep due to inactivity for a chosen time, so
background work such as coding-agent runs can continue. The display can follow
its usual sleep settings or stay on during the session.

macOS controls sleep when you close the lid or choose **Apple menu → Sleep**.
The timer counts time spent asleep, and the Mac wakes on its normal schedule
or when you wake it. If the timer expired during sleep, StillWorking shows the
session as finished after wake.

While unplugged, StillWorking refuses to start at or below 20% battery and
ends a running session at that floor. Connecting power again leaves the app
idle until you start a new session. If StillWorking cannot verify the required
power state, it shows an error and ends or declines protection.

StillWorking runs as a regular user and owns its own macOS power assertions.
The project is licensed under [MIT](LICENSE).

## Use the timer

1. Open StillWorking from the menu bar. Choose 15 minutes, 30 minutes, or any
   whole hour from 1 through 12 hours. Select **Custom** for a whole-minute
   duration from 1 minute to 168 hours.
2. Choose whether to **Keep display on** and select **Start**. Keeping the
   display on may delay automatic locking, depending on your settings.
3. The menu bar shows the remaining time and the panel shows the active mode.
   Editing the panel leaves the running session as it is. **Replace Timer**
   starts a new session for the full selected duration. **Stop** ends the
   session early. Closing the panel leaves the timer running.

A fresh launch opens inactive and preselects the last successful duration and
mode. First use starts with 30 minutes and **Keep display on** selected. In the
panel, use Tab and Shift–Tab to move focus and Space to activate a focused
control. Press Return or Enter to start or replace a timer with a valid duration
when the Duration menu is closed.

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
Xcode 26.6 on an Apple silicon Mac running macOS 26.6.2. See the
[local verification record](docs/local-verification.md) for tested behavior
and outstanding observations.

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
- [Local verification record](docs/local-verification.md)
- [Glossary](GLOSSARY.md)
- [Platform research and earlier closed-lid investigation](docs/research.md)
