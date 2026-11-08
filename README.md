# Not Yet

An open-source macOS tool being designed to temporarily prevent automatic sleep,
with a choice of allowing or preventing automatic display sleep.

The primary audience is people who do not use a terminal. The first milestone is
a locally usable menu bar application on the owner's Mac, with display-on mode
initially selected. A standalone CLI and public distribution are deferred. The
planned application will use Swift/SwiftUI and public macOS power APIs directly.
The project is licensed under [MIT](LICENSE). The local directory retains its
original working name, `one-more-sip`.

This repository currently contains design documentation only:

- [Design brief](docs/design.md): requirements, confirmed decisions, open questions,
  and draft completion criteria.
- [Research notes](docs/research.md): verified platform capabilities, limitations,
  comparable tools, and distribution constraints.
- [Glossary](GLOSSARY.md): shared terms for sessions and display modes.
- [Solution and implementation plan](docs/implementation-plan.md): concrete
  proposed behavior, architecture, work sequence, and verification.

Implementation will begin only after the owner approves the solution and plan.
