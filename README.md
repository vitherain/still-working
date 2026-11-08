# StillWorking

An open-source macOS tool being designed to keep a MacBook working for a chosen
duration, including with its lid closed while running on battery, so background
work such as coding agents can continue. Closed-lid operation on battery is the
primary first-version requirement; feasibility is not yet experimentally verified.

The primary audience is people who do not use a terminal. The first milestone is
a locally usable menu bar application on the owner's Mac that meets the closed-lid
battery requirement without an external monitor, with display-on mode initially
selected for open-lid use. Sessions end at 20% battery while unplugged. A one-time
administrator-approved setup is accepted; the narrowly scoped privileged
mechanism and independent restoration still need design and validation.

A standalone CLI and public distribution are deferred. The planned interface
uses Swift/SwiftUI. Ordinary idle protection uses public macOS power APIs.
The project is licensed under [MIT](LICENSE). The local directory and GitHub
repository are named `still-working`.

Status: the original baseline resources produced during grilling were approved
by the owner on 2026-11-08: this overview, design brief, research notes, glossary,
solution and implementation plan, and MIT license. Research caveats and required
runtime verification remain in effect. No application code has been created.

This repository currently contains design documentation and the license:

- [Consolidated functional specification](https://github.com/vitherain/still-working/issues/1): confirmed requirements,
  user stories, testing decisions, and the initial feasibility gate.

- [Design brief](docs/design.md): requirements, confirmed decisions, open questions,
  and acceptance criteria under revision for the main closed-lid requirement.
- [Research notes](docs/research.md): verified platform capabilities, limitations,
  comparable tools, and distribution constraints.
- [Glossary](GLOSSARY.md): shared terms for sessions and display modes.
- [Solution and implementation plan](docs/implementation-plan.md): the original
  approved baseline and the pending closed-lid architecture revision.

The owner subsequently confirmed closed-lid operation on battery as the primary
feature. The original idle-only baseline does not fulfill this requirement; the
consolidated functional specification is now published as GitHub issue #1. The
closed-lid mechanism, independent restoration, and target-machine verification
remain implementation gates; publication is not proof of technical feasibility.


## FAQ — planned behavior

### Why might Apple menu → Sleep not work while a timer is active?

The mechanism used to keep a closed MacBook working may also block manual
system sleep while the timer is active. **Select Stop in StillWorking first.**
Wait for confirmation that StillWorking has released its protection, then choose
Apple menu → Sleep. If stopping reports a restoration error, resolve that error
before relying on normal sleep behavior.

This is an accepted product limitation, not proof that a particular mechanism
works on the target Mac. The exact behavior and restoration will be verified
before the first version is declared complete.
