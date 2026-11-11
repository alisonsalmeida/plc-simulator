# Backlog

## Next

- [ ] I/O bit forcing (Forces ON/OFF) with indicators in data table and status bar
- [ ] Bundled curriculum examples: motor reversing with interlock, star-delta starter, batch counter (ADD/MOD), complete tank process
- [ ] Compile the program to IR/bytecode instead of interpreting the tree (spec M1)

## Done
- [x] Remaining curriculum instructions: MOD (modulo/batches), XPY/EXPT (power), SWP (swap bytes), ONS (one-shot rising)
- [x] F8 Data File (32-bit float) and INT <-> REAL conversion for flow and tank volume
- [x] RSLogix-style window chrome, stage 2: project tree, data files, find/replace, status bar
- [x] Parallel branch placement (drop contacts in parallel to create or expand branches easily)
- [x] Move already-placed instructions and branches on rungs (drag and drop to reposition)
- [x] Visual drop target points on the rung wire while dragging instructions; drop anywhere on stretchy wire
- [x] Instruction dialog fix: scrollable layout, analog bit address auto-normalization (e.g. I:1.0 -> I:1.0/0), Enter navigates fields
- [x] Vibrant active I/O green and full-energized rung wire colorization (green 2px rail-to-rail)
- [x] Digital and Analog I/O tabs in IoPanel with expandable real-time waveform charts on analog channels
- [x] Analog signal noise generator with enable/disable toggle for hysteresis demonstration
- [x] Analog I/O: input sliders in the I/O panel (volts / mA) and analog output example (AO module, desktop app)
- [x] Desktop app target instead of web (`flutter build linux` verified)
- [x] Bitwise logic instructions: AND, OR, XOR, NOT (Move/Logical tab)
- [x] Header menu bar with RSLogix menus: File, Edit, View, PLC, Help
- [x] Save/load programs as JSON
- [x] Internal HMI (supervisory) screen bound to data table tags
- [x] Resizable Data Table pane height (drag to grow or shrink)
- [x] Data table view and data movement instructions (N7, MOV/MVM/CLR, Data Files window)
- [x] Timer/Counter instructions: TON, TOF, RTO, CTU, CTD, RES (T4/C5 files)
- [x] Rebuild the editor UI with the RSLogix 500 look shown in `images/` (stage 1: ladder area and instruction toolbar)
- [x] Rung editing: build a circuit from scratch with drag and drop (insert/delete instructions and branches, edit addresses and symbols)
- [x] Instruction symbols as swappable assets (SVG files, one mapping in code)
- [x] Contacts and coils slice: XIC, XIO, OTE, OTL, OTU, branches, I/O panel, RUN/STEP/STOP, bundled examples
