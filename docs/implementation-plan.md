# StillWorking — solution and implementation plan

Status: approved by the owner on 2026-11-08, including the shared understanding,
interaction details, architecture, implementation sequence, and acceptance
criteria. No application code or build configuration has been created.

Confirmed decisions and interview references are in the [design brief](design.md).
Platform evidence is in [research notes](research.md).

## Intended result

A small English-language menu bar application, `StillWorking.app`, built locally on
the owner's Mac. It offers finite sessions, a display-mode choice, a countdown,
replacement, and early stop. It uses Swift/SwiftUI and public macOS power APIs,
under the MIT license. AppKit may supplement SwiftUI.

Complete the first milestone by delivering the local app and documented
build/launch steps with the acceptance checks below. Public distribution, a CLI,
and GitHub setup are outside this milestone.

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
- Show actual current status and active display mode separately from edited
  selections for the next/replacement session.
- Provide the five confirmed presets and custom integer `Hours` and `Minutes`
  fields. Label the display toggle `Keep display on`.
- First use selects 30 minutes and display-on. Later starts prefill the last
  successfully used choices.
- Require explicit `Start` or `Replace Timer`. Editing inputs alone does not
  alter the active session. Provide `Stop` and `Stop Timer and Quit` while active;
  when inactive provide `Quit`.
- Natural expiry shows `Finished`; manual stop shows `Stopped`. Both remove the
  countdown and show the inactive icon. The app remains available, silently.
- Reopening the running `.app` shows the same panel and session, without a second
  instance or timer change. A cold launch opens inactive and presents the panel.

### Validation, errors, and preferences

- Accept integer hours 0–168 and minutes 0–59, totaling 1–10,080 minutes inclusive.
  For example, `0h 1m`, `1h 30m`, and `168h 0m` are valid; `0h 0m` and `168h 1m`
  are invalid. Presets use the same validation.
- Reject blank, fractional, negative, nonnumeric, and above-range input. Explain
  the issue inline and disable start/replacement until valid. Invalid draft
  input leaves an existing session unchanged.
- Save duration/mode only after successful start or replacement. Do not persist
  an active deadline or restore sessions. Invalid stored preferences fall back
  to first-use defaults.
- Start failure leaves the app inactive with a visible error. Replacement
  acquisition failure cleans up partial new resources and preserves the original
  running session, its deadline, and saved choices.
- Distinguish already-expired resources from unexpected cleanup failures. Report
  unexpected failures without falsely claiming protection has been released.

### Platform boundaries

- Prevent automatic idle system sleep and optionally automatic display sleep.
  Use public APIs, without synthetic input or private APIs.
- Do not promise to prevent manual sleep, lid-close sleep, low-battery/thermal
  sleep, or every forced sleep. Do not wake the Mac at the deadline.
- Do not change persistent power, screen-saver, or security settings. Briefly
  explain the display option's material limitation, for example:
  `Keeping the display on may delay automatic locking.` Provide concise help for
  the other sleep limitations. Do not promise unchanged locking in every setup.
- Closing a terminal does not affect this independently launched application.
  No shell setup, administrator helper, or background daemon is included.

## Approved technical solution

### Local project and interface

Use a standard Xcode project with one macOS app target and a focused unit-test
target. Use Apple frameworks without external packages or a project generator.

Use macOS 13 as the API/deployment baseline for `ContinuousClock`. Verify on
the owner's macOS 26.6.2 arm64 machine with the installed Xcode/SDK. This does not
constitute tested support for other macOS releases or Intel Macs.

Use an AppKit `NSStatusItem`, `NSPopover`, and application delegate, with a SwiftUI
panel hosted by `NSHostingController`. This small integration supports explicit
reopen through public APIs. Pure SwiftUI `MenuBarExtra` has no public presentation
binding on the selected baseline, making the exact reopen behavior less direct.
Use `LSUIElement` metadata for menu bar agent behavior.

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

## Implementation sequence

1. **Project and local launch:** create Xcode app/test targets, bundle metadata,
   status item, panel, and documented local build path. Verify launch, dismiss,
   reopen, and quit independently of a terminal.
2. **Session behavior:** implement validation, monotonic timing, replacement,
   remembered successful selections, and inactive/active/stopped/finished states.
   Add focused deterministic behavior tests with controlled time.
3. **Native integration:** implement acquisition, partial-failure cleanup,
   replacement, stop/quit cleanup, finite timeout, and wake reconciliation.
   Test failure paths and inspect actual app-owned assertions.
4. **Complete interaction:** connect presets/custom fields, mode, status,
   countdown, actions, keyboard operation, accessible labels, errors, and concise
   platform limitation help.
5. **Verify and document:** execute the checks below, inspect the native UI,
   fix task-caused regressions, and record working build/launch instructions,
   observed limitations, and any unexecuted checks.

This implementation sequence is approved. The current owner request covers
recording that approval, committing it, and pushing to the configured origin;
application implementation has not started. Do not change global Git configuration
or treat this documentation push as an application release.

## Verification and completion criteria

Use the full criteria in the [design brief](design.md), with this verification
split. Test behavior and ownership rather than implementation snapshots.

| Area | Required evidence |
| --- | --- |
| Local build and launch | App builds; focused tests pass; double-click launch works on the owner's Mac. Document actual tools and build/install/remove steps. |
| Duration | Test 1 minute, every preset, an intermediate value, and 168 hours. Reject zero, huge/overflow input, negatives, fractions, blanks, nonnumeric input, and 168h 1m. No seven-day wait is required. |
| Timing | Controlled elapsed time covers progress, exact expiry, no negative countdown, sleep-inclusive advance, and independence from calendar clock changes. |
| Replacement | Replace 20 minutes remaining with 30 minutes and another mode: one committed session, 30 minutes from replacement, correct mode. Draft edits alone have no effect. |
| Errors | Fail first and second assertion acquisition, including during replacement: partial cleanup, original valid session preserved, visible error, saved choices unchanged. Cover expired IDs and unexpected release failures separately. |
| Native assertions | Inspect app-owned idle system/display assertions in both modes, replacement, stop, expiry, quit, and process exit. Leave other applications' assertions untouched. |
| Real idle behavior | Observe system staying awake during a supported session and display behavior in both modes under actual target settings. After release this app's protection disappears; immediate sleep is not required. |
| Sleep/wake | Observe real sleep/wake with time remaining, and expiry during sleep. Verify reconciliation and document native timeout behavior. |
| Lifecycle | Reopen reveals the same session. Process exit releases protection; a subsequent cold launch is inactive with remembered inputs. Coordinate a real restart check with the owner if not already observed. |
| Interface | Exercise presets, custom fields, mode, start, replace, stop, dismiss, reopen, and quit. Inspect long countdown width, keyboard access, and accessible control labels. |
| Quiet completion | Countdown disappears, icon is inactive, panel shows finished, app remains available. No completion sound or notification permission request. |
| Settings and limits | No persistent settings changes. Record observed display/locking behavior without universal claims. |

Real sleep, display-idle observations, restart, and system clock changes can
interrupt the owner's desktop. Coordinate these observations; do not automatically
reboot, log out, or change clock/power/security settings. Controlled-time tests
cover most timing cases without those interventions but do not replace the
listed native observations. Report any unexecuted required check as outstanding
rather than claiming full milestone completion.

## Explicitly later

Public name checks, CLI and command naming, localization beyond English,
automatic login launch, indefinite/scheduled
sessions, broader compatibility promises, download packaging, notarization,
Developer Program costs, and public update delivery are outside this plan.

## Approval record

Approved on 2026-11-08 by the owner's explicit instruction to mark all resources
produced during grilling as approved, then commit and push. This includes the
routine details and verification criteria in this plan. Approval is complete;
implementation and all runtime checks remain to be carried out.

## Scope-change hold: closed-lid operation on battery

After approving the baseline, the owner requested continued background work
with the MacBook lid closed and no power adapter. The baseline's ordinary IOPM
assertions and no-helper architecture do not establish this capability.

Before publishing the consolidated specification or implementing this extension:

1. Confirm whether a one-time administrator-approved setup and a narrowly scoped
   privileged component are acceptable as a product requirement. This preference
   is distinct from permission to install or change anything on the owner's Mac.
2. Investigate a bounded mechanism and verify it on the actual target hardware
   and macOS, including battery operation without an external display if required.
3. Define reliable restoration independent of UI survival, native-state readback,
   battery/power-source behavior, timeout, stop, quit, crash, and uninstall paths.
4. Revise the architecture, test seams, scope, and acceptance criteria accordingly.
   Do not claim support from documentation or other applications alone.

Existing deterministic session tests remain useful. This extension also needs
independent real-system observations of lid closure and continued computation;
ordinary idle assertions or a running countdown alone are insufficient evidence.
No implementation or power-management mutation has been performed.
