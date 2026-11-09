# PLC Simulator

Ladder-logic PLC simulator for teaching (SLC 500 style mnemonics), built for the CLP II course
at Centro de Ensino Literatus.

- `packages/plc_core/` — pure Dart engine: bit addresses, data table, scan cycle.
- `lib/` — Flutter app (web/Linux): ladder view with live power flow, I/O panel, RUN/STEP/STOP.

Current slice: contacts and coils (XIC, XIO, OTE, OTL, OTU) with parallel branches, using
bundled example programs. Spec: `literatus/docs/plc-simulator-mvp-spec.md`.

## Commands

```
make check   # analyze + tests (app and engine)
make run     # run in Chrome
make web     # release build in build/web
```
