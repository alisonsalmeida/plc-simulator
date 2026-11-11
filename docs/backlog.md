# Backlog

## Next

- [x] Set 1: R6 Control data file, Shift Registers (BSL, BSR) and FIFO/LIFO queues (FFL, FFU, LFL, LFU)
- [x] Fix editor exceptions: Scrollbar unattached ScrollController in LadderView
- [x] Modular I/O and chassis hardware configuration (RSLogix-style IO Configuration tab/window: customizable chassis/rack with slots for CPU, digital input, digital output, analog input/output, and communication modules with visual assembly view of the physical PLC rack)
- [x] Set 2: Sequencer instructions: SQO (Sequencer Output), SQC (Sequencer Compare), SQL (Sequencer Load)
- [x] Configurable peripheral mapping to chassis modules (allow assigning thumbwheel and 7-segment display to dedicated digital I/O slots/words to avoid competing with default I:0/O:0)
- [x] Free hardware I/O mapping: allow mapping the 16 digital inputs bank to slot N, digital outputs bank to slot Y, analog inputs/outputs to dedicated slots, and persist mapping in project save
- [ ] Set 3: File/Array batch operations: COP (Copy File), FLL (Fill File), AVE (Average File), SRT (Sort File)
- [ ] Set 4: Program flow and subroutines: JSR (Jump Subroutine), SBR (Subroutine Header), RET (Return), JMP, LBL, MCR (Master Control Reset), TND (Temporary End)
- [ ] Process simulation window: Bottle Filling Line (animated 2D simulation with conveyor, fill nozzle, capper, reject piston, BSL/BSR shift registers and R6 control file)
- [ ] Compile the program to IR/bytecode instead of interpreting the tree (spec M1)

## Done
- [x] Pluggable simulation peripherals: 7-segment display (BCD and direct), thumbwheel switch in dedicated Periféricos tab with up to 4 digits
- [x] BCD conversion instructions: TOD (To BCD) and FRD (From BCD)
- [x] I/O bit forcing (Forces ON/OFF) with indicators in data table and status bar
- [x] Bundled curriculum examples: motor reversing with interlock, star-delta starter, batch counter (ADD/MOD), complete tank process
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
