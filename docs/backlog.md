# Backlog

## Next

- [ ] Analog input sliders in the I/O panel simulating voltage and current sensors
- [ ] RSLogix-style window chrome, stage 2: project tree, data files, find/replace, status bar
- [ ] Compile the program to IR/bytecode instead of interpreting the tree (spec M1)

## Done
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
