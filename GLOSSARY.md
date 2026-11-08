# Temporary sleep prevention

Status: baseline terminology approved on 2026-11-08; closed-lid terminology
updated to reflect the owner's subsequent primary-requirement clarification.

Terms for the timed macOS sleep-prevention experience. Mode names here describe
the domain; user-facing wording is specified in the approved implementation plan.

## Language

**Keep-awake session**:
A finite period during which computer work is kept running, including closed-lid
operation on battery, with a chosen open-lid display mode. It ends when its
duration expires, the user stops it early, the user quits the application, or
the battery floor is reached while running on battery.
_Avoid_: Permanent power setting

**Computer-only mode**:
A session mode that prevents automatic computer sleep while allowing the display
to turn off according to its normal settings.

**Display-on mode**:
A session mode that also prevents automatic display sleep while the lid is open.
Closed-lid operation is shared by all keep-awake sessions, independently of this
display choice.

**Closed-lid operation**:
Continued computer work with the MacBook lid closed, including operation on
battery without a power adapter or external monitor.
_Avoid_: Display sleep

**Battery floor**:
The fixed minimum charge level of 20% at which a battery-powered keep-awake
session ends early and allows normal sleep behavior.

**Remaining time**:
The time left until the end of a keep-awake session, counting actual system sleep
toward its duration.

**Session replacement**:
Ending the current session in favor of a new one whose full chosen duration
begins at replacement, using the newly selected display mode.
_Avoid_: Extension, added time
