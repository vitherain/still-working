# Temporary sleep prevention

Status: approved by the owner on 2026-11-08.

Terms for the timed macOS sleep-prevention experience. Mode names here describe
the domain; user-facing wording is specified in the approved implementation plan.

## Language

**Keep-awake session**:
A finite period of protection against automatic computer sleep, with a chosen
display mode, ending when its duration expires, the user stops it early, or the
user explicitly quits the application.
_Avoid_: Permanent power setting

**Computer-only mode**:
A session mode that prevents automatic computer sleep while allowing the display
to turn off according to its normal settings.

**Display-on mode**:
A session mode that prevents both automatic computer sleep and automatic display
sleep; it is not a promise to override manual sleep or lid closure.

**Remaining time**:
The time left until the end of a keep-awake session, counting actual system sleep
toward its duration.

**Session replacement**:
Ending the current session in favor of a new one whose full chosen duration
begins at replacement, using the newly selected display mode.
_Avoid_: Extension, added time
