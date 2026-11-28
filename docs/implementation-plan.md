# StillWorking — solution and implementation plan

Status: original baseline approved on 2026-11-08 and restored to idle-only
protection on 2026-11-22. [Local verification](local-verification.md) tracks
the implemented app and remaining target Mac observations.

Confirmed decisions and interview references are in the [design brief](design.md).
Platform evidence is in [research notes](research.md).

## Intended result

A small English-language menu bar application, `StillWorking.app`, built locally
on the owner's Mac. It keeps an awake Mac working past the normal idle-sleep
threshold for a finite session. It offers two display modes, a countdown,
replacement, and early stop. Sessions also end at the fixed 20% unplugged battery
floor. The app uses Swift/SwiftUI and public macOS power APIs under the MIT license.
AppKit may supplement SwiftUI.

Complete the first milestone by delivering the local app and documented
build/launch steps with the acceptance checks below. Public distribution and a CLI
are outside this milestone.

## Approved interaction details

These approved details complete the confirmed requirements. Text and visual
polish may be refined without changing behavior.

### Panel and menu bar

- Run as a menu bar agent without a Dock icon. Clicking the status item opens a
  compact panel; dismissing the panel leaves the app and session running.
- Inactive: show the app icon without a countdown. Distinguish active and
  inactive states without relying only on color.
- Active: show remaining time using monospaced digits. Format durations below
  one hour as `M:SS`, and longer ones as `H:MM:SS` with total hours through
  `168:00:00`. Round positive remaining fractions up for display; finish only
  when the actual deadline is reached.
- Show the current timer status and active display mode alongside the duration
  selection for the next start or replacement.
- Provide the [duration presets](design.md#duration-and-remembered-selections)
  and custom integer `Hours` and `Minutes` fields. Label the display toggle
  `Keep display on`.
- First use selects 30 minutes and display-on. Later starts prefill the last
  successfully used choices.
- Require explicit `Start` or `Replace Timer` to apply the selected duration.
  While active, `Keep display on` applies immediately and preserves the deadline.
  Provide `Stop` and `Stop Timer and Quit` while active. When inactive, provide `Quit`.
- Natural expiry shows `Finished`; manual stop shows `Stopped`. Both remove the
  countdown and show the inactive icon. The app remains available, silently.
- Reopening the running `.app` shows the same panel and session, without a second
  instance or timer change. A manual cold launch opens inactive and presents
  the panel. See [Launch at Login](design.md#launch-at-login) for automatic launch.

### Validation, errors, and preferences

- Accept integer hours 0–168 and minutes 0–59, totaling 1–10,080 minutes inclusive.
  For example, `0h 1m`, `1h 30m`, and `168h 0m` are valid; `0h 0m` and `168h 1m`
  are invalid. Presets use the same validation.
- Reject blank, fractional, negative, nonnumeric, and above-range input. Explain
  the issue inline and disable start/replacement until valid. Invalid draft
  input still allows a live display mode change.
- Save the duration after successful start or replacement. Save the display
  mode when a start, replacement, or live change successfully applies it.
  A cold launch starts inactive. Invalid stored preferences fall back to
  first-use defaults.
- Start failure leaves the app inactive with a visible error. Replacement
  acquisition failure cleans up partial new resources and preserves the original
  running session, its deadline, and saved choices.
- Distinguish already-expired resources from unexpected cleanup failures. Report
  unexpected failures without falsely claiming protection has been released.

### Platform boundaries

- Prevent automatic idle system sleep and optionally automatic display sleep.
  Use public APIs, without synthetic input or private APIs.
- Leave manual Sleep, lid closure, and low-battery and thermal sleep to macOS.
  Configure the timer without any wake schedule. Verify manual Sleep and normal
  lid-close sleep in both display modes on the target Mac.
- Do not change persistent power, screen-saver, or security settings. Briefly
  explain the display option's material limitation, for example:
  `Keeping the display on may delay automatic locking.` Provide concise help for
  the other sleep limitations. Do not promise unchanged locking in every setup.
- Run as a regular user using app-owned assertions. Closing a terminal does
  not affect a session started in the application.

## Approved technical solution

### Local project and interface

Use a standard Xcode project with one macOS app target and a focused unit-test
target. Use Apple frameworks without external packages or a project generator.

Use macOS 13 as the API/deployment baseline for `ContinuousClock`. Verify on
the owner's macOS 26.6.2 arm64 machine with the installed Xcode/SDK. This does not
constitute tested support for other macOS releases or Intel Macs.

Use an AppKit `NSStatusItem`, `NSPanel`, and application delegate, with SwiftUI
content hosted by `NSHostingController`. The panel is positioned under the
status item on the invoking display and ordered out on dismissal. This
integration supports explicit reopen through public APIs. Pure SwiftUI
`MenuBarExtra` has no public presentation binding on the selected baseline,
making the exact reopen behavior less direct. Use `LSUIElement` metadata for
menu bar agent behavior.

Produce a local `.app` with local/ad-hoc signing as required by the toolchain.
Verify double-click launch and document exact successful build/install/remove
steps. Paid Developer ID signing and notarization remain deferred.

### Session state and timing

Keep one session owner inside the app, separate from UI draft fields. It manages
state, deadline, actual mode, preferences, and protection ownership. Provide small
test seams for elapsed time and native power calls, without a generic plugin
system or future CLI service.

Use a `ContinuousClock` monotonic deadline that counts actual system sleep.
Calculate remaining time from the deadline rather than decrementing a counter.
A periodic refresh updates the label; it does not define elapsed time. On wake,
reconcile the deadline, finish expired sessions, and ensure unexpired protection
remains valid. Calendar clock changes must not shift the duration. Store neither
a wake alarm nor a cross-reboot active deadline.

### Native protection ownership

Hold an idle system sleep assertion and, in display-on mode, an idle display
sleep assertion through public IOPM APIs. The app owns the IDs and releases them
on stop, finish, and quit. macOS process-exit cleanup also covers crashes.
Do not spawn a `caffeinate` child.

Acquire the replacement's assertions before committing the new session and
releasing the old set. On acquisition failure, release partial new resources
and preserve the original session. Temporary overlap prevents a protection gap;
there is one committed user session.

Use the native finite timeout/release facility as a safeguard against a hung
app, not the timing source of truth. Verify its sleep/wake and clock-change
behavior during integration. Reconcile expired IDs and unexpired protection on
wake; tolerate IDs already released by the OS. Adjust timeout handling if native
observations reveal a mismatch with the confirmed elapsed-time rule.

Read power source and battery charge via public macOS APIs. On battery, refuse
start at or below 20%, and end a running session when it reaches the floor or
external power is disconnected at or below it. Reconcile the policy on wake
before resuming any unexpired protection. If a required reading is unavailable,
report the error and release or decline protection. Recovery of external power
or battery charge requires a new manual start after cutoff.

## Implementation sequence

1. **Project and local launch:** create Xcode app/test targets, bundle metadata,
   status item, panel, and documented local build path. Verify launch, dismiss,
   reopen, and quit independently of a terminal.
2. **Session behavior:** implement validation, monotonic timing, replacement,
   remembered successful selections, and inactive/active/stopped/finished states.
   Add focused deterministic behavior tests with controlled time.
3. **Native integration:** implement acquisition, partial-failure cleanup,
   replacement, stop/quit cleanup, finite timeout, wake reconciliation, and
   the unplugged battery cutoff. Test failure paths and inspect app-owned assertions.
4. **Complete interaction:** connect presets/custom fields, mode, status,
   countdown, actions, keyboard operation, accessible labels, errors, and concise
   platform limitation help.
5. **Verify and document:** execute the checks below, inspect the native UI,
   fix task-caused regressions, and record working build/launch instructions,
   observed limitations, and any unexecuted checks.

## Verification and completion criteria

Use the full criteria in the [design brief](design.md), with this verification
split. Test behavior and ownership rather than implementation snapshots.

| Area | Required evidence |
| --- | --- |
| Local build and launch | App builds; focused tests pass; double-click launch works on the owner's Mac. Document actual tools and build/install/remove steps. |
| Duration | Test 1 minute, every preset, an intermediate value, and 168 hours. Reject zero, huge/overflow input, negatives, fractions, blanks, nonnumeric input, and 168h 1m. No seven-day wait is required. |
| Timing | Controlled elapsed time covers progress, exact expiry, no negative countdown, sleep-inclusive advance, and independence from calendar clock changes. |
| Replacement | With 20 minutes remaining, select 30 minutes and confirm the original countdown continues. Replace the timer and verify a single 30-minute session with the selected mode. |
| Live display mode | Toggle both ways while the timer is active. Verify the checkbox, active mode, unchanged deadline and system assertion, and the addition or removal of the display assertion. Relaunch to verify the last applied mode and the last started duration. |
| Errors | Fail first and second assertion acquisition, including during replacement: partial cleanup, original valid session preserved, visible error, saved choices unchanged. Cover expired IDs and unexpected release failures separately. |
| Native assertions | Inspect app-owned idle system/display assertions in both modes, replacement, stop, expiry, quit, and process exit. Leave other applications' assertions untouched. |
| Real idle behavior | Observe system staying awake during a supported session and display behavior in both modes under actual target settings. After release this app's protection disappears; immediate sleep is not required. |
| Sleep/wake | In both display modes, observe Apple-menu Sleep and normal lid-close sleep with an active timer. On wake, verify reconciliation with time remaining and after expiry. Confirm that expiry did not wake the Mac and document native timeout behavior. |
| Battery | Exercise above, at, and below 20%; start rejection; power-source changes; unavailable readings; wake reconciliation; and manual restart after cutoff. Use controlled battery input for boundaries. |
| Lifecycle | Reopen reveals the same session. Process exit releases protection; a subsequent cold launch is inactive with remembered inputs. Coordinate a real restart check with the owner if not already observed. |
| Interface | Exercise presets, custom fields, mode, start, replace, stop, dismiss, reopen, and quit. Inspect long countdown width, keyboard access, and accessible control labels. |
| Quiet completion | Countdown disappears, icon is inactive, panel shows finished, app remains available. No completion sound or notification permission request. |
| Settings and limits | No persistent power or security settings changes. Record observed display/locking behavior without universal claims. |

Real sleep, display-idle observations, restart, and system clock changes can
interrupt the owner's desktop. Coordinate these observations; do not automatically
reboot, log out, or change clock/power/security settings. Controlled-time tests
cover most timing cases without those interventions but do not replace the
listed native observations. Report any unexecuted required check as outstanding
rather than claiming full milestone completion.

## Explicitly later

Public name checks, CLI and command naming, localization beyond English,
indefinite or scheduled sessions, broader compatibility promises, download
packaging, notarization, Developer Program costs, and public update delivery
are outside this plan.

## Approval record

Approved on 2026-11-08 by the owner's explicit instruction to mark all resources
produced during grilling as approved, then commit and push. This includes the
routine details and verification criteria of the original plan. The 2026-11-22
scope decision is recorded in the design brief. Implementation and runtime
verification results are in the [local verification record](local-verification.md).
