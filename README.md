# PLC Simulator

Ladder-logic PLC simulator for teaching (SLC 500 style mnemonics), built for the CLP II course
at Centro de Ensino Literatus.

- `packages/plc_core/` — pure Dart engine: bit addresses, data table, scan cycle.
- `lib/` — Flutter app (web/Linux): ladder view with live power flow, I/O panel, RUN/STEP/STOP.

Current slice: contacts and coils (XIC, XIO, OTE, OTL, OTU), timers (TON, TOF, RTO), counters
XX Spec: `literatus/docs/plc-simulator-mvp-spec.md`.

## Assets

Ladder symbols are SVG files in `assets/ladder/` (`xic`, `xio`, `ote`, `otl`, `otu`, `ton`, `tof`, `rto`, `ctu`, `ctd`, `res`, `mov`, `mvm`, `clr`, `equ`, `neq`, `les`, `leq`, `grt`, `geq`, `lim`, `branch`).
`lib/theme/ladder_assets.dart` is the only mapping from mnemonic to file and is used by both
the rung view and the palette. To change a symbol, replace its SVG (or edit that map). Draw
black strokes on a transparent background: the app tints them with the theme colors
(energized / off). Instruction symbols use a 24x32 viewBox (the wire is drawn by the app on
both sides; timers, counters and RES use 28x24 palette icons, and the app draws their box in the rung itself); the branch icon is only shown in the palette (48x32).

## Commands

```
make check   # analyze + tests (app and engine)
make run     # run in Chrome
make web     # release build in build/web
```
