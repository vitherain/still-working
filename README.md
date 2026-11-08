# StillWorking

An open-source macOS tool being designed to temporarily prevent automatic sleep,
with a choice of allowing or preventing automatic display sleep.

The primary audience is people who do not use a terminal. The first milestone is
a locally usable menu bar application on the owner's Mac, with display-on mode
initially selected. A standalone CLI and public distribution are deferred. The
planned application will use Swift/SwiftUI and public macOS power APIs directly.
The project is licensed under [MIT](LICENSE). The local directory and GitHub
repository are named `still-working`.

Status: all resources produced during grilling were approved by the owner on
2026-11-08: this project overview, the design brief, research notes, glossary,
solution and implementation plan, and MIT license. Research caveats and required
runtime verification remain in effect. No application code has been created.

This repository currently contains design documentation and the license:

- [Design brief](docs/design.md): requirements, confirmed decisions, open questions,
  and approved completion criteria.
- [Research notes](docs/research.md): verified platform capabilities, limitations,
  comparable tools, and distribution constraints.
- [Glossary](GLOSSARY.md): shared terms for sessions and display modes.
- [Solution and implementation plan](docs/implementation-plan.md): concrete
  approved behavior, architecture, work sequence, and verification.

The solution and implementation plan are approved for implementation. This
approval-recording change does not start application development.
