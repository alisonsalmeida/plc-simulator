# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-11

### Added
- **RSLogix 500-style Editor UI:**
  - Classic industrial desktop chrome with header menu bar (Arquivo, Editar, Exibir, Comunicação, Ajuda).
  - Project Tree window listing controller properties, program routines (LAD 2 - MAIN, subroutines), data files, and modular I/O configuration.
  - Interactive ladder logic view with rail-to-rail dynamic green power flow visualization and editable rungs.
  - Drag-and-drop instruction placement, parallel branch editing, and in-place operand dialogs.
  - Find and Replace dialog for symbols and addresses across rungs.
  - Resizable Data Table pane supporting hexadecimal, decimal, and binary views.

- **Modular I/O & Chassis Hardware Configuration:**
  - Customizable SLC 500-style chassis rack (modular slots for CPU, digital inputs, digital outputs, analog I/O).
  - Interactive visual assembly view of physical modules in the PLC rack.
  - Free hardware I/O mapping: map digital inputs, digital outputs, and analog channels to arbitrary chassis slots.

- **Simulation Peripherals:**
  - Pluggable BCD / direct thumbwheel switch (1 to 4 digits).
  - Glowing 7-segment LED display with BCD and direct segment decoding.
  - Unassociated peripheral state (`⊘ Não Associado`) allowing peripherals to remain unbound from chassis slots until explicitly assigned.
  - Rich analog I/O panel with real-time waveform charts (`AnalogWaveformChart`), noise injection toggles (hysteresis demonstration), and 0–10V / 4–20mA physical scaling.

- **Complete SLC 500 Instruction Set (`packages/plc_core`):**
  - **Bit Logic:** `XIC`, `XIO`, `OTE`, `OTL`, `OTU`, `ONS`.
  - **Timers & Counters:** `TON`, `TOF`, `RTO`, `CTU`, `CTD`, `RES`.
  - **Comparison:** `EQU`, `NEQ`, `LES`, `LEQ`, `GRT`, `GEQ`, `LIM`.
  - **Compute & Math:** `ADD`, `SUB`, `MUL`, `DIV`, `NEG`, `SQR`, `SCL`, `MOD`, `XPY` / `EXPT`.
  - **Move & Logic:** `MOV`, `MVM`, `CLR`, `AND`, `OR`, `XOR`, `NOT`, `SWP`, `TOD`, `FRD`.
  - **Shift Registers & Queues:** `BSL`, `BSR`, `FFL`, `FFU`, `LFL`, `LFU` with `R6` control elements.
  - **Sequencers:** `SQO`, `SQC`, `SQL`.
  - **File Batch Operations:** `COP`, `FLL`, `AVE`, `SRT`.
  - **Program Flow & Subroutines:** `JSR`, `SBR`, `RET`, `JMP`, `LBL`, `MCR`, `TND`.

- **Educational Bundled Curriculum Examples:**
  - Motor reversing with electrical interlock.
  - Star-delta starter with timer transition.
  - Batch counter with modulo and reset.
  - Complete industrial tank level and flow process with analog scaling.
  - 7-Segment display with BCD conversion (`TOD` / `FRD`).
  - Bit shifting and FIFO queues.
  - Sequencer stepping.

- **I/O Bit Forcing:**
  - Live forces ON/OFF with visual indicator flags in data table and status bar.
