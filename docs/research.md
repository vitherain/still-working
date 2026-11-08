# Research notes

Status: approved by the owner on 2026-11-08 as research input to the design.
Sources were checked on 2026-11-07. Approval does not mean runtime validation: no
sleep-prevention experiment has been run. Source-based findings, inferences,
uncertainties, and required verification remain distinguished below.

## Sleep prevention

The installed `man caffeinate` and Apple's
[caffeinate source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/caffeinate/caffeinate.c)
describe distinct protections:

- `-i`: prevent idle system sleep.
- `-d`: prevent idle display sleep.
- `-t`: set a timeout in seconds.
- With no protection flags, idle system sleep prevention is the default.
- `-w` can bind protection to a monitored process's lifetime.

For example, `caffeinate -i -t 1800` requests 30 minutes of idle system sleep
prevention; `caffeinate -di -t 1800` also prevents automatic display sleep.
These examples illustrate capabilities, not a product CLI API. In round 7, the
owner selected direct public macOS APIs rather than spawning this command.

Apple documents that
[idle system sleep prevention](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridlesystemsleep)
does not cover lid closure, explicit sleep, low battery, or every other cause of
system sleep. The product must not promise to keep a closed MacBook awake.

[Idle display sleep prevention](https://developer.apple.com/documentation/iokit/kiopmassertiontypepreventuseridledisplaysleep)
does not itself turn on an already sleeping display. Preventing display sleep
must not be presented as a guarantee against all display-off or system-sleep causes.

Releasing this tool's protection does not command immediate sleep. Other
applications may still prevent sleep, and macOS retains its normal policy.

The original process cannot survive a restart. Restoring a session would require
separate behavior. Terminal closure depends on process ownership and signals;
using `caffeinate` alone does not specify a reliable product lifecycle.
The owner chose elapsed time including actual sleep and no active-session
recovery after crash/restart. The approved plan selects ContinuousClock; runtime
verification is still outstanding.

### Timing and process lifetime

[ContinuousClock](https://developer.apple.com/documentation/swift/continuousclock)
includes system sleep, while `SuspendingClock` excludes it; see the official
[Swift clock proposal](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0329-clock-instant-duration.md).
The local Swift interfaces mark both available from macOS 13.0.
[mach_continuous_time](https://developer.apple.com/documentation/kernel/1646199-mach_continuous_time)
also includes system sleep and is available from macOS 10.12 in the local SDK.
These monotonic sources support elapsed-time measurement independent of calendar
clock adjustments. This is an API-based inference, not a tested application.
Including sleep in a clock does not cause application code to run during sleep
or wake the computer at the deadline; the app must reconcile state on wake.

Public IOPM APIs can create and release idle system/display sleep assertions
directly. Apple documents cleanup when the owning process exits or crashes in
[power-management release notes](https://developer.apple.com/library/archive/releasenotes/Darwin/RN-IOKitPowerManagment/index.html);
the current [PowerManagement source](https://github.com/apple-oss-distributions/PowerManagement/blob/main/pmconfigd/PMAssertions.c)
also handles process-exit cleanup. With direct APIs, the app owns the assertion;
with a wrapper, `caffeinate` owns it and requires explicit lifecycle management.
The owner selected direct APIs in round 7; no runtime implementation exists yet.

### Display sleep versus locking

Display sleep, the screen saver, and screen locking are distinct behaviors.
Apple's [Lock Screen settings](https://support.apple.com/en-gb/guide/mac-help/mh11784/27/mac/27)
can tie password requirements to the screen saver or display turning off.
Inference: preventing a trigger can delay automatic locking in some settings.
No universal guarantee that locking remains unchanged has been established.
Use supported public APIs and test the target configuration; do not promise a
particular screen-saver or locking outcome based only on a display assertion.

## Local development environment

Read-only checks found macOS 26.6.2 (25G83), arm64, Xcode 26.6 (17F113), Apple
Swift 6.3.3, and macOS SDK 26.5. The SDK is available under
`/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk`.
Version and SDK discovery commands succeeded; SDK enumeration emitted sandbox
cache/FSEvents warnings. No compilation or prototype has been attempted.

### Native menu bar interface and protection backend

The local SDK marks SwiftUI
[MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) and
its [window style](https://developer.apple.com/documentation/swiftui/menubarextrastyle/window)
available from macOS 13.0. The window style supports a popover-like interface with
custom layout and controls. It matches duration fields, mode toggle, status,
and start/stop/replacement actions. Native Swift/SwiftUI was selected in round 7;
the SwiftUI/AppKit integration is specified in the plan approved on 2026-11-08.

For the approved reopen behavior, use public AppKit
[NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem) and
[NSPopover](https://developer.apple.com/documentation/appkit/nspopover/show%28relativeto%3Aof%3Apreferrededge%3A%29)
with a SwiftUI [NSHostingController](https://developer.apple.com/documentation/swiftui/nshostingcontroller).
The public [reopen delegate](https://developer.apple.com/documentation/appkit/nsapplicationdelegate/applicationshouldhandlereopen%28_%3Ahasvisiblewindows%3A%29)
can present the existing panel. `MenuBarExtra`'s public `isInserted` binding
controls item presence, not panel presentation; no direct presentation binding
was found on the macOS 13 baseline. The AppKit alternative avoids introspection
or third-party dependencies for this requirement.

[LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement)
supports menu bar agent behavior without a Dock icon. Verify reopen by opening
the actual `.app`; popover presentation requires a visible anchor, so menu bar
visibility and long-countdown width need real UI inspection.

Apple's `caffeinate` source creates the same public IOPM assertion types that an
application can create directly. The native app can therefore provide the
requested behaviors without spawning the command. A wrapper would require
managing a separate process and its lifecycle; the owner chose direct APIs.

[IOPMAssertionCreateWithDescription](https://developer.apple.com/documentation/iokit/1557078-iopmassertioncreatewithdescripti)
supports a system-managed timeout with an explicit release action. Local SDK
comments explain that timeout can release protection even if the app is hung.
The precise timeout semantics across actual system sleep have not been verified;
use the selected elapsed-time deadline and reconcile on wake rather than assuming
the OS timeout alone fulfills the product's timing rule.

Creating both system and display assertions requires separate calls. Startup
and replacement must clean up partial success. On replacement failure, any new
partial assertions should be released and the existing valid session retained.
IDs may already have expired through system timeout, so cleanup must handle that
case. These are implementation constraints, not additional user-facing features.

## License options

The [MIT license](https://opensource.org/license/mit) permits reuse, modification,
redistribution, and sale, subject to retaining its copyright and permission
notice. It does not require distributing modified source code.

[GPLv3](https://opensource.org/license/gpl-3.0) is a copyleft alternative: conveying
a covered modified work carries GPL licensing and corresponding-source
obligations. Private modifications are distinct from distribution. These notes
are a high-level comparison; the license text governs actual conditions.

In round 7 the owner selected MIT, now applied in the repository's `LICENSE`.

## Existing alternatives

- [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) is an MIT-licensed
  macOS menu bar application built around `caffeinate`. It already offers timed
  and indefinite activation, direct downloads, and Homebrew installation. Its
  documentation explicitly excludes closed-lid operation.
- [Amphetamine](https://apps.apple.com/us/app/amphetamine/id937984704?mt=12) is a free
  Mac App Store alternative with timed sessions, display options, and additional
  automation. Its advanced capabilities must not be attributed to `caffeinate`
  without separate verification.

Inference: a GUI around `caffeinate` is not itself a new capability. In round 2,
the owner explicitly chose to continue with a new, simple product focused on
understandable interaction and execution despite this overlap. Specific UX
benefits remain to be defined; no comparative advantage has been established.

## Completion notifications

[Apple's notification authorization documentation](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
describes authorization for user-visible notification alerts and sounds.
System completion notifications add an authorization flow and must still allow
correct timer operation when permission is denied. In-app status alone does not
require a notification permission request. In round 6, the owner chose silent
in-app completion feedback without system notifications or sound.

## Direct application distribution

Apple describes Developer ID signing and notarization as the standard path for
new applications downloaded outside the App Store:
[Gatekeeper and first launch](https://support.apple.com/en-us/102445),
[notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

Unsigned or unnotarized downloads may require a user exception in Privacy &
Security. That route has more first-launch friction, and managed-device policies
may prevent exceptions. Even signed, notarized downloads normally have an initial
confirmation; do not promise a completely prompt-free first launch.

The [Apple Developer Program](https://developer.apple.com/programs/enroll/) lists
membership at USD 99 per year, with regional pricing in local currency. Whether
membership is already available and whether the owner accepts release costs are
open questions. Local development can proceed without buying membership now.

In round 3, the owner chose a local-only first milestone and deferred public
distribution and membership cost decisions. No public distribution channel,
purchase, signing identity, or App Store release has been selected or authorized.

## Addendum: requested closed-lid operation on battery

Investigated on 2026-11-08 after baseline approval. This addendum records a new
requirement and findings; it is not an approved implementation or tested claim
of support on the target Mac.

- The owner wants background agents to continue with the MacBook lid closed
  while running on battery. The existing idle-sleep assertions are insufficient
  for this requirement. Apple's archived
  [power-management release notes](https://developer.apple.com/library/archive/releasenotes/Darwin/RN-IOKitPowerManagment/index.html)
  explicitly distinguish assertions from forced lid-close sleep. This agrees
  with the limitation already recorded in the approved baseline.
- The maintainer's [Amphetamine Power Protect documentation](https://github.com/x74353/Amphetamine-Power-Protect)
  describes an additional installer, administrator password/Touch ID approval,
  an application script, and a sudoers configuration. It documents Apple Silicon
  closed-display issues on external-power transitions. This is primary evidence
  that comparable behavior requires extra mechanisms in that application, not
  evidence that StillWorking's unmodified baseline can provide it.
- The maintainer's
  [closed-display fail-safe source](https://github.com/x74353/Amphetamine-Enhancer/blob/master/Xcode%20Project/Amphetamine%20Enhancer/Scripts/amphetamine-enhancer-cdmManager.sh)
  checks application/session presence and triggers restoration when protection
  should no longer be active. A system-wide override therefore needs recovery
  beyond the normal cleanup of process-owned IOPM assertions.
- The locally installed pmset manual states that changing its settings requires
  root and describes its system-wide settings storage. It does not document the
  specific disablesleep control in the inspected settings list; do not assume
  its exact persistence, sleep, crash, or reboot semantics without verification.

Inference: a privileged override/helper or another separately verified mechanism
is a candidate for investigation. It changes installation and failure recovery
relative to the baseline. No supported public idle assertion has been found that
alone fulfills the new requirement. Feasibility and compatibility remain open;
we have not changed pmset, installed scripts, modified sudoers, closed the lid,
or run a prototype.

A target-model query through sysctl was blocked by the sandbox; the exact model
has not been established in this investigation. The OS reports macOS 26.6.2.
The product decision still needed is whether administrator-approved setup is
acceptable. Later tests must cover the actual target Mac, finite duration,
battery/power transitions, restoration, and continued computation with the lid
closed rather than trusting only the app's displayed active state.
