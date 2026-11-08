# StillWorking — design brief

Status: original idle-sleep baseline approved on 2026-11-08. The owner has since
confirmed closed-lid operation on battery as the main feature of the first
version. One-time administrator-approved setup, a 20% battery floor, and
operation without an external display are confirmed. The exact mechanism,
independent restoration, and revised verification plan remain under design. Application implementation has not started.
Discussion is in Czech; repository content is in English.

## Goal and primary audience

Keep a MacBook executing background work during a finite keep-awake session,
including after closing its lid while disconnected from the power adapter.
This is the main feature of StillWorking and is required for the first local
version; an idle-only application does not meet the goal. Every timer start must
provide this behavior under the supported conditions, rather than requiring a
separate closed-lid toggle.

Make this behavior understandable and accessible without requiring a particular
shell or manual shell configuration. A coding-agent run is a concrete primary
scenario. Operation without an external display is explicitly required.

The primary first-release audience is ordinary macOS users who do not use a
terminal (owner confirmation, round 1, Q2: A).

The owner deliberately chose to build a new, simple product despite the overlap
with existing tools (round 2, Q3: A). Its intended value is clear interaction and
execution according to the owner's preferences; feature novelty is not required.
This is a product direction, not evidence of superiority over existing tools.
See [research notes](research.md) for the overlap.

Background work with the display allowed to sleep and use that keeps the display
on have equal first-release priority (round 2, Q4: C). A specific personal example
was initially unspecified; the later confirmed primary scenario is continued
background agent work with the lid closed on battery. Both display choices remain
available for open-lid operation.

Domain terms are defined in the [glossary](../GLOSSARY.md). These terms describe
behavior and do not prescribe the final UI wording.

## Requirements from the initial brief

The original requirements were approved with the baseline implementation plan.
The owner subsequently confirmed closed-lid operation on battery as the primary
requirement; the corresponding architecture revision remains pending.

- Prevent computer sleep for a duration expressed in minutes or hours, including
  lid-close sleep on battery as the primary first-version requirement. The
  implementation must validate actual support instead of promising it from
  ordinary idle assertions alone.
- Let the user choose whether the display may turn off automatically or should
  remain on.
- Show the active mode and remaining time.
- Allow the user to end the timer early.
- On expiry or early termination, release this tool's sleep prevention and leave
  subsequent behavior to macOS settings and other applications.
- Target macOS only for the first version.
- Do not require a particular shell or manual edits to `.zshrc`.
- Develop as an open-source project under the MIT license.

## Confirmed decisions and constraints

| ID | Decision | Basis |
| --- | --- | --- |
| D1 | Initially use `/Users/vitherain/personal_dev/one-more-sip`; the project has since been renamed to `/Users/vitherain/personal_dev/still-working`. | Round 1, Q1: A; subsequent owner rename. |
| D2 | Prioritize ordinary macOS users who do not use a terminal. | Round 1, Q2: A. |
| D3 | Prepare the project and documentation before implementation; obtain explicit approval of the solution and implementation plan. | Initial brief. |
| D4 | Initialize a local repository on `main` if the directory is outside any repository. | Initial brief; checked and completed. |
| D5 | Initially defer GitHub setup. The repository now uses `https://github.com/vitherain/still-working.git` as origin. Do not change global Git configuration. | Initial brief; subsequent repository setup. |
| D6 | Build a new, simple product despite the known overlap with existing tools; prioritize understandable interaction and execution. | Round 2, Q3: A. |
| D7 | Give background-work and display-on scenarios equal first-release priority. | Round 2, Q4: C. |
| D8 | Deliver a menu bar application first; defer any standalone CLI. | Round 3, Q5: A. |
| D9 | Select display-on mode on first use, with an option to allow automatic display sleep. Later selections are remembered under D15. | Round 3, Q6: B; round 5, Q12: A. |
| D10 | Target a locally usable application on the owner's Mac first. Defer public distribution, signing/notarization commitments, and membership cost decisions. | Round 3, Q7: C. |
| D11 | Offer duration presets and custom entry in hours and minutes. Values and range are specified in D14. | Round 4, Q8: A. |
| D12 | Show an active-state icon and remaining time directly in the menu bar; expose the active display mode and stop action on opening the app's menu/panel. | Round 4, Q9: A. |
| D13 | Keep one active session. An explicit replacement action starts the newly selected duration from that moment with the selected display mode; it does not add to the old remaining time. | Round 4, Q10: A. |
| D14 | Presets: 15 minutes, 30 minutes, 1 hour, 2 hours, and 4 hours. First-use duration: 30 minutes. Custom duration: 1 minute through 168 hours (7 days), in whole minutes. | Round 5, Q11: B. |
| D15 | Remember the last used duration and display mode for preselection before manually starting a subsequent session. | Round 5, Q12: A. |
| D16 | Explicitly quitting the application ends any active session and releases its protection. Merely dismissing the menu/panel leaves the session running. | Round 5, Q13: A. |
| D17 | Count actual system sleep toward the session duration. On wake, continue only the unexpired remainder; if the duration elapsed during sleep, the session is finished. Do not wake the Mac at expiry. | Round 6, Q14: A. |
| D18 | After an application crash or Mac restart, open inactive with remembered input selections. Do not restore an interrupted session automatically or offer recovery. | Round 6, Q15: A. |
| D19 | Complete silently: remove the countdown, show an inactive icon, and expose completion status in the menu/panel. Keep the app available for another session; no completion sound or system notification. | Round 6, Q16: A. |
| D20 | Originally select the name Not Yet; this naming decision is superseded by D24. | Round 7, Q17: B; subsequent owner rename. |
| D21 | Use a native Swift/SwiftUI application with direct public macOS power-management APIs, rather than spawning `caffeinate`; AppKit may supplement SwiftUI. | Round 7, Q18: A. |
| D22 | Use the MIT license, permitting reuse including closed-source derivatives subject to its terms. | Round 7, Q19: A. |
| D23 | Approve all resources produced during grilling, including the routine details and completion criteria, and record the approval with a commit and push. | Explicit owner instruction, 2026-11-08. |
| D24 | Rename the product to StillWorking, the GitHub repository to `vitherain/still-working`, and the local directory to `/Users/vitherain/personal_dev/still-working`. Preserve repository identity/history and the pending closed-lid scope extension. | Explicit owner instruction, 2026-11-08. |
| D25 | Make continued work with the lid closed and no power adapter the main first-version feature, applying whenever the timer starts under supported conditions. The mechanism and safeguards still need specification and verification. | Explicit owner clarification, 2026-11-08. |
| D26 | Accept one-time administrator-approved setup and a narrowly scoped privileged component. This is an architecture preference, not authorization to install or mutate the target Mac. | Q21: A, 2026-11-08. |
| D27 | End a battery-powered session when charge reaches 20%, releasing this tool's protection and allowing normal sleep behavior. Use a fixed threshold in the first version. | Q22: A, 2026-11-08. |
| D28 | Require closed-lid operation on battery without an external monitor or other attached equipment. | Q23: A, 2026-11-08. |
| D29 | Accept that manual Apple-menu Sleep may be blocked during a session; the user stops the timer first. Explain this in the project README/FAQ. This does not select or validate the native mechanism. | Q24: A, 2026-11-08. |

At project setup, the directory was empty and outside any Git repository. It was
initialized on `main`; the initial documentation and agent configuration have
since been committed and the GitHub origin configured.

## First milestone scope

Deliver a locally usable menu bar application on the owner's Mac, with finite
sessions that keep background work running with the lid closed on battery, both
open-lid display modes, active status, remaining time, and early stop. Closed-lid
operation is an acceptance gate for this milestone, not a deferred enhancement.
Display-on mode is the initial selection. Confirmed behavior is recorded here;
routine details and the work sequence are specified in the approved
[solution and implementation plan](implementation-plan.md).

Duration selection includes presets and custom hours/minutes. While active, the
menu bar shows a distinct active icon and countdown. Opening its menu/panel shows
the current display mode and a stop control. The panel layout is specified in
the approved plan; visual polish may be refined without changing behavior.

To change an active session, the user explicitly replaces it: with 20 minutes
remaining, replacing it with 30 minutes means 30 minutes from replacement, not
50 minutes. The replacement uses the newly selected display mode. Replacement
must not create multiple concurrent sessions. On failure, preserving the old
valid session and reporting the failure is required by the approved plan.

### Duration and remembered selections

- Presets: 15 minutes, 30 minutes, 1 hour, 2 hours, and 4 hours.
- First-use selection: 30 minutes, display-on mode.
- Custom duration: 1 minute through 168 hours inclusive, in whole minutes.
- The maximum is a product limit, not a claimed macOS restriction.
- Subsequent manual starts are prefilled with the last used duration and display
  mode. Interrupted active sessions are not restored after a crash or restart.

### Application lifetime

Dismissal of the menu/panel leaves the application and current session running.
Explicit quit ends the session, releases this application's protection, and
removes its menu bar item. When active, the quit action should clearly describe
both effects ("Stop Timer and Quit" in the approved plan).

The session's duration includes actual system sleep. With 20 minutes remaining,
sleeping for 5 minutes leaves 15 minutes after waking; sleeping for 30 minutes
means the session is finished on wake. The app does not wake the Mac at expiry.
Measure elapsed time independently of system clock adjustments using the
approved ContinuousClock deadline and wake reconciliation.

After a crash or restart, the application opens inactive and offers the last used
duration/mode for a new manual start. It does not recover the interrupted session.
No detached timer continuing after an intentional quit is part of this milestone.
Repeated-open and terminal-independence rules are approved below.

A battery floor of 20% ends an unplugged session early and releases its
protection; work may stop before the chosen duration expires. The floor is
fixed in the first version. Low-battery, emergency, and thermal protections must
remain effective. This exception is part of the primary keep-awake contract.

On natural completion, remove the countdown, switch to the inactive icon, and
show completion status when the menu/panel is opened. The app stays available
for the next manual start. Do not request notification permission for completion;
there is no completion sound or system notification in this milestone.

### Deferred work

A standalone CLI is deferred. Public download and first-launch requirements,
signing, notarization, release updates, and associated costs remain open for a
later distribution milestone. A working local application must not be described
as a public-ready release. No Developer Program purchase has been authorized.

## Approved implementation details and deferred concepts

- A future CLI is outside the first milestone; its eventual command name and
  syntax remain undecided.
- Exact panel layout, display toggle wording, countdown format, local build
  setup, and stop/replacement controls are specified in the approved plan.
- Use a sleep-inclusive monotonic deadline with wake reconciliation and a
  system-managed assertion timeout as an additional safeguard; verify timeout
  behavior rather than relying on it as the timer's source of truth.

### Approved routine behavior

The owner approved these details together with the solution and implementation
plan on 2026-11-08.

- Reopening an already running application reveals its existing menu/panel and
  session without starting, replacing, or extending anything. Replacement
  requires the explicit replacement action.
- Normal application use is independent of a terminal; closing a terminal does
  not affect a session started in the application.
- Invalid duration input shows a specific validation message and does not start
  or replace a session. Empty, negative, nonnumeric, fractional, zero-total, and
  above-maximum durations are invalid.
- Failure to start protection must be visible; do not show a running countdown
  as though protection succeeded. On replacement failure, retain the previous
  valid session where possible and explain the failure.
- Use English for the initial user interface, consistent with the owner's
  instruction that repository outputs are in English. Localization can be
  considered for a later milestone.
- Automatic user-session launch at login and scheduled/indefinite sessions remain
  outside this milestone. Preserve security settings. Any privileged setup or
  temporary system-wide sleep override needed for closed-lid operation must be
  explicitly designed, restored reliably, and approved separately.

## Remaining questions and deferred decisions

The original idle-only baseline was approved. The new primary closed-lid battery
requirement, administrator-approved setup, fixed 20% battery floor, and absence
of an external display are confirmed. Independent restoration, exact native
mechanism, and revised verification are still being specified.
The [consolidated functional specification](https://github.com/vitherain/still-working/issues/1)
records these requirements, including the resolved manual-sleep limitation and
the initial technical feasibility gate.

New source-based finding: the candidate global sleep override can also block
manual Apple-menu Sleep, and its setting can persist independently of the UI.
The owner accepted stopping the timer before manually choosing Sleep (Q24: A).
This limitation must remain visible in the project README/FAQ.
Its effects on emergency sleep paths and recovery must be assessed before
selecting a mechanism; do not promise unchanged system protections.

Implementation must verify native timeout behavior across sleep/wake, process
exit cleanup, and display/screen-saver/locking behavior on the target Mac. These
are technical verification tasks, not unanswered user-preference questions.
The earlier exclusion of lid-close sleep is superseded as a product requirement
by D25. Ordinary idle assertions still cannot establish that capability. Do not
promise verified closed-lid support, overrides of emergency/thermal shutdown, or
unchanged automatic locking before the relevant mechanism and conditions are
validated.

The source repository and origin already exist. Application distribution remains
explicitly deferred: public name availability, broader macOS/hardware support,
download format, installation on another Mac, Developer ID/notarization, membership cost,
and release/update process. None blocks the approved local implementation.

## Acceptance criteria under revision

The original criteria were approved with the baseline on 2026-11-08. The main
closed-lid criterion below reflects the subsequent owner clarification. The
20% unplugged battery exception and no-external-display condition are confirmed;
recovery details and the final verification procedure remain under design.

1. On the owner's Mac, a non-terminal user can start a finite duration from the
   menu bar application without editing shell files or running terminal commands
   during normal use.
2. During an active duration, background computation continues after the MacBook
   lid is closed while disconnected from its power adapter on the supported
   target machine. Verify continued computation and system sleep state, not just
   a running countdown or an idle assertion. No external monitor or power
   adapter may be attached. Test the 20% unplugged battery cutoff and preserve
   emergency/thermal protections.
   This is the main acceptance criterion; idle-only protection is insufficient.
3. With the lid open, the display option controls whether automatic display
   sleep is prevented. It does not disable the shared closed-lid requirement.
   On initial use, display-on mode is selected; the user can choose either mode.
4. The active mode and remaining time can be inspected, and the timer can be
   stopped early. During a session, an active icon and remaining time appear in
   the menu bar; the menu/panel exposes the current mode and stop action.
5. Expiry and early stop release this tool's prevention without forcing immediate
   sleep or changing persistent macOS power settings.
6. Agreed repeat-start, lifecycle, and invalid-input scenarios have explicit,
   verified outcomes before release.
7. The local build, installation, launch, and removal steps are documented and
   verified on the owner's Mac. Any developer-tool or local signing requirements
   are stated explicitly. Public-download testing on another Mac is deferred to
   the distribution milestone.
8. All five presets and custom hours/minutes can start a session. Custom input
   accepts 1 minute and 168 hours, includes intermediate whole-minute durations,
   and rejects values outside that range. Inline feedback and disabled start/
   replacement for invalid input are required by the approved implementation plan.
9. Replacing a session with 20 minutes remaining by a 30-minute session produces
   one session with 30 minutes remaining, using the newly selected display mode.
10. First use preselects 30 minutes and display-on mode. After successfully using
    a custom duration and another mode, subsequent manual-start controls prefill
    those selections.
11. Dismissing the menu/panel leaves the session active. Explicitly quitting
    removes the menu bar item and releases this application's protection.
12. Starting with 20 minutes remaining, 5 minutes of actual sleep leaves about
    15 minutes on wake; 30 minutes of sleep results in a finished session. A
    calendar clock adjustment does not extend or shorten elapsed duration.
13. After a crash or restart, opening the app shows it inactive with the last
    successfully used selections; it does not restore the interrupted session.
14. Natural completion removes the menu bar countdown and changes to the inactive
    icon; the menu/panel reports completion. No completion sound or notification
    permission request occurs, and the app stays open for another manual start.
15. Reaching the fixed 20% battery floor while unplugged ends the session and
    releases its protection. Starting at or below the floor must not establish
    a session; report why it is unavailable. While external power is connected,
    the unplugged battery floor does not end a session. Disconnecting power at
    or below the floor ends it; reconnecting power does not restart it.
16. Document and verify the accepted one-time administrator setup and uninstall
    path. Verify that the app cannot show full closed-lid protection as active
    until the required mechanism is available and its state has been checked.
17. The README/FAQ explains that Apple-menu Sleep may be blocked during an active
    timer and instructs the user to select Stop first. Verify the stated behavior
    and restoration on the target Mac; this limitation is explicitly accepted.

## Approval record

On 2026-11-08 the owner explicitly instructed: "Mark all resources produced
during grilling as approved. Then commit and push." This approves this brief,
the [solution and implementation plan](implementation-plan.md), completion
criteria, project overview, glossary, research notes, and MIT license.

Approval is recorded for future implementation; this change records approval and
publishes documentation only. No application code, build, or runtime verification
has been performed. Deferred distribution decisions and research caveats remain
in effect.

## Subsequent scope change: closed-lid operation on battery

Requested by the owner after baseline approval and confirmed on 2026-11-08 as
the primary first-version requirement before publishing the consolidated
specification. This requirement supersedes the baseline's lid-close exclusion.

The owner needs StillWorking to prevent a MacBook from sleeping when its lid is
closed while disconnected from the power adapter, so background work such as
agent runs can continue. This requirement applies to every active timer and is
the main purpose of the tool. It is required for the first version, while the
exact privileged mechanism and safeguards remain unresolved.

The baseline remains approved for its existing behavior, but it does not satisfy
this extension. Ordinary caffeinate/IOPM idle assertions do not provide the
required closed-lid guarantee. The exact mechanism, recovery behavior, compatibility, and acceptance tests
are not yet experimentally verified. The owner accepted one-time administrator
setup, a fixed 20% unplugged battery floor, and operation without an external
display in Q21–Q23. Installation or system changes still require a concrete
reviewable procedure before execution.

The consolidated functional specification records a technical feasibility gate
for this architectural change. In particular, revisit the baseline exclusion of privileged
helpers and the assumption that all protection disappears with the UI process.
Do not silently turn an application-owned assertion into a system-wide override.
A time-bounded override needs reliable restoration on expiry, stop, quit, crash,
and failed startup/replacement, plus a defined battery policy. Restoring settings
must respect their pre-session state and other software rather than assuming
that sleep was originally enabled.

No system settings have been changed and no closed-lid experiment or helper
installation has been authorized or performed. See the research addendum for
primary-source evidence and unresolved technical questions. Q21–Q24 are resolved.
