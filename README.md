# StillWorking

StillWorking is an open-source macOS menu bar app in development. It will keep
an awake Mac from going to sleep due to inactivity for a chosen time, so
background work such as coding-agent runs can continue. The display can follow
its usual sleep settings or stay on during the session.

macOS controls sleep when you close the lid or choose **Apple menu → Sleep**.
The timer counts time spent asleep, and the Mac wakes on its normal schedule
or when you wake it. If the timer expired during sleep, StillWorking shows the
session as finished after wake.

The first milestone is a locally usable app with a countdown, early stop, and a
20% battery cutoff while unplugged. It uses app-owned public macOS power
assertions and runs as a regular user. The project is licensed under [MIT](LICENSE).

## Project status

The design is documented. App implementation and runtime verification are pending.

- [Functional specification](https://github.com/vitherain/still-working/issues/1)
- [Design brief and acceptance criteria](docs/design.md)
- [Implementation and verification plan](docs/implementation-plan.md)
- [Glossary](GLOSSARY.md)
- [Platform research and earlier closed-lid investigation](docs/research.md)
