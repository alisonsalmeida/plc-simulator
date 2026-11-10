# PLC Simulator

Ladder-logic PLC simulator for teaching (SLC 500 style mnemonics), built for the CLP II course
at Centro de Ensino Literatus.

- `packages/plc_core/` — pure Dart engine: bit addresses, data table, scan cycle.
- `lib/` — Flutter app (web/Linux): ladder view with live power flow, I/O panel, RUN/STEP/STOP.

Current slice: contacts and coils (XIC, XIO, OTE, OTL, OTU), timers (TON, TOF, RTO), counters
XX Spec: `literatus/docs/plc-simulator-mvp-spec.md`.

## Assets

Ladder symbols are SVG files in `assets/ladder/` (`xic`, `xio`, `ote`, `otl`, `otu`, `ton`, `tof`, `rto`, `ctu`, `ctd`, `res`, `mov`, `mvm`, `clr`, `equ`, `neq`, `les`, `leq`, `grt`, `geq`, `lim`, `add`, `sub`, `mul`, `div`, `neg`, `sqr`, `scl`, `branch`).
`lib/theme/ladder_assets.dart` is the only mapping from mnemonic to file and is used by both
the rung view and the palette. To change a symbol, replace its SVG (or edit that map). Draw
black strokes on a transparent background: the app tints them with the theme colors
(energized / off). Instruction symbols use a 24x32 viewBox (the wire is drawn by the app on
both sides; timers, counters and RES use 28x24 palette icons, and the app draws their box in the rung itself); the branch icon is only shown in the palette (48x32).

## Supervisório (HMI)

The **Ladder / Supervisório** toggle in the app bar swaps the main area for an internal HMI
screen. Add widgets from the palette (Botão, Chave, Lâmpada, Display, Barra), each bound to a
data table address (`B3:0/0`, `T4:0/DN`, `N7:0`, `T4:0.ACC`, ...); addresses are validated with
the `plc_core` parser. Widgets read and write the live data table in RUN and STOP, like the
Data Files window. Drag a widget by its label to move it; right-click (or long-press the
label) for Editar / Excluir. The layout is kept in memory only (no save/load yet).

## Analog I/O

SLC 500 style modules, shown below the digital I/O in the right-hand panel. Each channel has a
range selector (`0–10 V` or `4–20 mA`); the data table holds raw counts like the real module.

| Module | Slot | Words | Range | Raw counts |
|---|---|---|---|---|
| Analog input (1746-NI4) | 1 | `I:1.0` … `I:1.3` (bits: `I:1.0/3`) | 0–10 V | 0 … 32767 |
| | | | 4–20 mA | 3277 … 16384 (0 mA = 0) |
| Analog output (1746-NO4V/NO4I) | 2 | `O:2.0`, `O:2.1` (bits: `O:2.0/3`) | 0–10 V | 0 … 32764 |
| | | | 4–20 mA | 6242 … 31208 (display up to 21 mA = 32764) |

The student moves a slider in volts / milliamps; the value stays across scans (writing `I:1.x`
from Data Files goes through the same path). The ladder writes the outputs (MOV / SCL) and the
panel shows the physical value read-only; analog outputs go to 0 on STOP. Default ranges: `I:1.0`
4–20 mA, other inputs and `O:2.0` 0–10 V, `O:2.1` 4–20 mA. Example: "Analógico: sensor 4–20 mA →
saída 0–10 V".

## Commands

```
make check   # analyze + tests (app and engine)
make run     # run in Chrome
make web     # release build in build/web
flutter build linux   # desktop release build in build/linux/x64/release/bundle
```
