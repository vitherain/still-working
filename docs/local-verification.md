# Local verification

The target tested on 2026-11-22 was a MacBookPro17,1 with macOS 26.6.2
(25G83), Xcode 26.6 (17F113), and the macOS 26.5 SDK. The app targets macOS 13.
Runtime evidence here applies to the tested Mac and OS.

## Build and install

Use the [README commands](../README.md#build-and-launch-locally). The full
arm64 XCTest suite passed all 19 tests. The Release build succeeded and
`codesign --verify --strict StillWorking.app` verified its ad-hoc signature.
An app bundle copied under the user's Applications directory launched through
Launch Services as the logged-in regular user. After Quit and a separate forced
process-exit check, the test bundle moved to Trash from the regular user session.

## Observed with the Release app

| Check | Result |
| --- | --- |
| First use | Opened inactive with 30 minutes and display-on selected. |
| Presets | Started all five from the panel. The menu bar showed `15:00`, `30:00`, `1:00:00`, `2:00:00`, and `4:00:00`. |
| Custom input | Started 1-minute and 168-hour sessions. `168h 1m` showed the range explanation and disabled replacement while the original session and its assertions continued. |
| Assertions | Both modes owned `PreventUserIdleSystemSleep`. Display-on also owned `PreventUserIdleDisplaySleep`. The 1-minute session showed a 60-second `TimeoutActionRelease` on both IDs. The 168-hour computer-only session showed a finite timeout of about 604,800 seconds. |
| Replacement | Replacing a display-on timer with 168 hours in computer-only mode removed both old IDs and left one new system ID. The menu bar displayed `168:00:00` and exposed “168 hours remaining” to assistive technology. |
| Dismiss and reopen | Dismissing and reopening preserved the process, countdown, and draft. |
| Expiry and Stop | The real 1-minute session reached `Finished`, removed the countdown, and released both IDs while the app stayed available. Manual Stop showed `Stopped` and released its ID. The app has no completion sound or notification permission path. |
| Quit and process exit | The active Quit control and a forced exit of the test process each removed that process's assertions. The next launch had a new PID, an inactive app, and the last successful duration and mode. Other processes' assertions remained present. |
| Accessibility and keyboard | The accessibility tree exposed the status item, remaining time, actual mode, Hours, Minutes, and named actions. The active state adds the timer symbol and countdown. Tab navigated the fields, typing updated the duration, and Space activated focused controls including Start, Replace Timer, Stop, and Stop Timer and Quit. |

A separate public API probe on the same Mac let a 3-second display assertion
time out while awake. macOS removed its properties and returned
`kIOReturnBadArgument` on a later release of the expired ID. The app checks
whether the ID still has properties before treating that result as expired.

## Controlled checks

The XCTest suite advances the elapsed clock independently of wall time. It
covers the exact deadline and rounding, wake with protection missing or power
unavailable, invalid and overflowing durations, battery charge above, at, and
below 20%, external power and unplugging, reconnection without auto-resume,
and assertion acquisition and cleanup failures. The replacement test starts
with 20 minutes remaining and verifies a new 30-minute timer with the selected
mode and no protection gap.

## Target Mac observations still outstanding

The run above verified app-owned assertions while other processes, including
`caffeinate`, held assertions of their own. The system and display outcomes
below require a coordinated session with the Mac owner.

- With the lid open and power and display settings held constant, observe
  background activity beyond the normal idle threshold in both display modes.
  Verify display sleep and automatic locking separately. Record the power
  source, configured idle limits, and other processes' relevant assertions.
- In each mode, try Apple menu **Sleep** and normal lid closure in a setup where
  macOS would ordinarily sleep. In one run, wake before the deadline and check
  the reduced time and assertion state. In another run, wake after the
  deadline and check `Finished` and the sleep/wake log for a wake at expiry.
- Coordinate any real OS restart check with the owner. A process exit and cold
  relaunch were observed, and the app's saved preferences contain only the
  last successful duration and mode.

Use `pmset -g custom` for the configured idle limits, `pmset -g assertions` to
identify assertions by process, and `pmset -g log` for recorded sleep and wake
events. Run these observations with the device's normal settings and record any
other software or accessories that affect them.
