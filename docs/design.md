# Not Yet — design brief

Status: design ready for owner review. No implementation has been approved.
Discussion is in Czech; repository content is in English.

## Goal and primary audience

Make temporary prevention of automatic macOS sleep understandable and accessible
without requiring a particular shell or manual shell configuration.

The primary first-release audience is ordinary macOS users who do not use a
terminal (owner confirmation, round 1, Q2: A).

The owner deliberately chose to build a new, simple product despite the overlap
with existing tools (round 2, Q3: A). Its intended value is clear interaction and
execution according to the owner's preferences; feature novelty is not required.
This is a product direction, not evidence of superiority over existing tools.
See [research notes](research.md) for the overlap.

Background work with the display allowed to sleep and use that keeps the display
on have equal first-release priority (round 2, Q4: C). A specific personal example
has not been supplied; neither scenario takes precedence by assumption.

Domain terms are defined in the [glossary](../GLOSSARY.md). These terms describe
behavior and do not prescribe the final UI wording.

## Requirements from the initial brief

These are explicit owner needs. Detailed first-release behavior remains to be
agreed; this list is not an approved implementation specification.

- Prevent automatic computer sleep for a duration expressed in minutes or hours.
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
| D1 | Use `/Users/vitherain/personal_dev/one-more-sip` as the local project directory. | Round 1, Q1: A. |
| D2 | Prioritize ordinary macOS users who do not use a terminal. | Round 1, Q2: A. |
| D3 | Prepare the project and documentation before implementation; obtain explicit approval of the solution and implementation plan. | Initial brief. |
| D4 | Initialize a local repository on `main` if the directory is outside any repository. | Initial brief; checked and completed. |
| D5 | Defer GitHub repository creation, visibility, and remote configuration. Do not change global Git configuration. | Initial brief. |
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
| D20 | Name the first local application Not Yet. Keep the approved local directory `one-more-sip`; check public name availability during the distribution milestone. | Round 7, Q17: B. |
| D21 | Use a native Swift/SwiftUI application with direct public macOS power-management APIs, rather than spawning `caffeinate`; AppKit may supplement SwiftUI. | Round 7, Q18: A. |
| D22 | Use the MIT license, permitting reuse including closed-source derivatives subject to its terms. | Round 7, Q19: A. |

The directory existed and was empty, with no enclosing Git repository. A local
repository has been initialized on `main`; no commit has been made.

## First milestone scope

Deliver a locally usable menu bar application on the owner's Mac, with finite
sessions, both display modes, active status, remaining time, and early stop.
Display-on mode is the initial selection. Confirmed behavior is recorded here;
remaining routine details and the work sequence are proposed in the
[solution and implementation plan](implementation-plan.md) for owner approval.

Duration selection includes presets and custom hours/minutes. While active, the
menu bar shows a distinct active icon and countdown. Opening its menu/panel shows
the current display mode and a stop control. The exact visual layout is open.

To change an active session, the user explicitly replaces it: with 20 minutes
remaining, replacing it with 30 minutes means 30 minutes from replacement, not
50 minutes. The replacement uses the newly selected display mode. Replacement
must not create multiple concurrent sessions. On failure, preserving the old
valid session and reporting the failure is proposed in the plan.

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
both effects (for example, "Stop Timer and Quit"); exact UI copy is not final.

The session's duration includes actual system sleep. With 20 minutes remaining,
sleeping for 5 minutes leaves 15 minutes after waking; sleeping for 30 minutes
means the session is finished on wake. The app does not wake the Mac at expiry.
Measure elapsed time independently of system clock adjustments; the precise
technical mechanism is still proposed rather than approved.

After a crash or restart, the application opens inactive and offers the last used
duration/mode for a new manual start. It does not recover the interrupted session.
No detached timer continuing after an intentional quit is part of this milestone.
Repeated-open and terminal-independence rules remain explicit recommendations
for final plan review below.

On natural completion, remove the countdown, switch to the inactive icon, and
show completion status when the menu/panel is opened. The app stays available
for the next manual start. Do not request notification permission for completion;
there is no completion sound or system notification in this milestone.

### Deferred work

A standalone CLI is deferred. Public download and first-launch requirements,
signing, notarization, release updates, and associated costs remain open for a
later distribution milestone. A working local application must not be described
as a public-ready release. No Developer Program purchase has been authorized.

## Proposals awaiting final plan approval

- Any future CLI command `moresip`, duration syntax such as `30m` / `2h`, a
  `--screen` option, and `status` / `stop` subcommands. A CLI is outside the first
  milestone, and its eventual command name is open after the product rename.
- Exact panel layout, display toggle wording, countdown format, local build
  setup, and stop/replacement control presentation are made concrete in the plan.
- Use a sleep-inclusive monotonic deadline with wake reconciliation and a
  system-managed assertion timeout as an additional safeguard; verify timeout
  behavior rather than relying on it as the timer's source of truth.

### Recommended routine behavior for plan review

These recommendations are pending approval of the final solution and plan;
they are not additional confirmed owner decisions.

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
- Do not add automatic launch at login, scheduled or indefinite sessions, or
  changes to persistent power/security settings in this milestone.

## Remaining questions and deferred decisions

The product decisions for the local milestone have been answered. The proposed
routine details, solution, acceptance criteria, and implementation plan still
require explicit owner approval before coding.

Implementation must verify native timeout behavior across sleep/wake, process
exit cleanup, and display/screen-saver/locking behavior on the target Mac. These
are technical verification tasks, not unanswered user-preference questions.
Do not promise prevention of forced sleep or lid-close sleep, or unchanged
automatic locking in every configuration.

Public distribution remains explicitly deferred: public name availability,
GitHub repository/visibility/remote, broader macOS/hardware support, download
format, installation on another Mac, Developer ID/notarization, membership cost,
and release/update process. None blocks a local implementation once approved.

## Draft observable completion criteria

Derived from the initial brief; to be refined and explicitly approved.

1. On the owner's Mac, a non-terminal user can start a finite duration from the
   menu bar application without editing shell files or running terminal commands
   during normal use.
2. During an active duration, the Mac does not enter automatic idle system sleep
   under supported, documented conditions.
3. The display option controls whether automatic display sleep is prevented.
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
   replacement for invalid input are proposed in the implementation plan.
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

## Approval gate

Review the [solution and implementation plan](implementation-plan.md), including
the routine recommendations and acceptance criteria. The owner must confirm a
shared understanding and authorize implementation. Until then, only project
preparation and documentation are authorized. Recommendations do not become
confirmed owner decisions merely by being written down.
