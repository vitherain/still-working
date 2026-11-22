# Temporary sleep prevention

Terms for the timed macOS sleep-prevention experience. Mode names here describe
the domain; user-facing wording is specified in the approved implementation plan.

## Language

**Keep-awake session**:
A finite period of protection against automatic idle system sleep, with a
chosen display mode. It ends at expiry, early stop, app quit, or the battery floor
while unplugged.
_Avoid_: Permanent power setting

**Computer-only mode**:
A session mode that prevents automatic idle system sleep while allowing the display
to turn off according to its normal settings.

**Display-on mode**:
A session mode that also prevents automatic idle display sleep.

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
