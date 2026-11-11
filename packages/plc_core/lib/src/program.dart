import 'address.dart';

/// Anything that can sit on a rung: an instruction or a parallel branch.
sealed class RungElement {
  const RungElement();
}

/// Time base of a timer: one tick of ACC.
enum TimeBase {
  second(1000, '1.0'),
  centisecond(10, '0.01');

  const TimeBase(this.milliseconds, this.label);

  /// Duration of one tick, in milliseconds.
  final int milliseconds;

  /// As printed by RSLogix, in seconds.
  final String label;
}

/// Largest preset of a timer or counter.
const maxPreset = 32767;

/// Everything that sits on a rung as a single instruction: bit instructions and the
/// timer/counter box instructions.
sealed class Instruction extends RungElement {
  const Instruction();

  /// Builds an instruction from its SLC 500 [mnemonic]: XIC, XIO, OTE, OTL, OTU (bit
  /// [address]); TON, TOF, RTO (`T4:n`, with [timeBase] and [preset]); CTU, CTD (`C5:n`,
  /// with [preset]); RES (`T4:n` or `C5:n`); MOV, MVM, CLR ([address] is the destination
  /// word; [source] and [mask] are word addresses or constants, the mask may be hex);
  /// EQU, NEQ, LES, LEQ, GRT, GEQ ([address] is Source A, a word address; [source] is
  /// Source B); LIM ([source] is the low limit, [address] the test value, [mask] the high
  /// limit; each a word address or constant); ADD, SUB, MUL, DIV ([source] is Source A,
  /// [mask] Source B, [address] the destination word); NEG, SQR ([source] is the source,
  /// [address] the destination); SCL ([source] is the source, [mask] the rate, [offset]
  /// the offset, [address] the destination; each source operand a word address or constant);
  /// AND, OR, XOR ([source] is Source A, [mask] Source B, [address] the destination word);
  /// NOT ([source] is the source, [address] the destination); MOD, XPY / EXPT ([source] is
  /// Source A, [mask] Source B, [address] the destination); SWP / SWAP ([source] is the
  /// source, [address] the destination); ONS (bit [address]).
  /// The extra arguments are ignored where they
  /// do not apply.
  ///
  /// Throws [ArgumentError] for an unknown mnemonic or a preset outside 0..[maxPreset], and
  /// [FormatException] for a bad address or operand.
  factory Instruction.create(
    String mnemonic,
    String address, {
    TimeBase timeBase = TimeBase.second,
    int preset = 0,
    String source = '',
    String mask = '',
    String offset = '',
  }) =>
      switch (mnemonic.toUpperCase()) {
        'XIC' => Xic(address),
        'XIO' => Xio(address),
        'OTE' => Ote(address),
        'OTL' => Otl(address),
        'OTU' => Otu(address),
        'TON' => Ton(address, timeBase, preset),
        'TOF' => Tof(address, timeBase, preset),
        'RTO' => Rto(address, timeBase, preset),
        'CTU' => Ctu(address, preset),
        'CTD' => Ctd(address, preset),
        'RES' => Res(address),
        'MOV' => Mov(source, address),
        'MVM' => Mvm(source, mask, address),
        'CLR' => Clr(address),
        'EQU' => Equ(address, source),
        'NEQ' => Neq(address, source),
        'LES' => Les(address, source),
        'LEQ' => Leq(address, source),
        'GRT' => Grt(address, source),
        'GEQ' => Geq(address, source),
        'LIM' => Lim(source, address, mask),
        'ADD' => Add(source, mask, address),
        'SUB' => Sub(source, mask, address),
        'MUL' => Mul(source, mask, address),
        'DIV' => Div(source, mask, address),
        'NEG' => Neg(source, address),
        'SQR' => Sqr(source, address),
        'SCL' => Scl(source, mask, offset, address),
        'AND' => And(source, mask, address),
        'OR' => Or(source, mask, address),
        'XOR' => Xor(source, mask, address),
        'MOD' => Mod(source, mask, address),
        'XPY' || 'EXPT' => Xpy(source, mask, address),
        'SWP' || 'SWAP' => Swp(source, address),
        'TOD' => Tod(source, address),
        'FRD' => Frd(source, address),
        'ONS' => Ons(address),
        'NOT' => Not(source, address),
        _ => throw ArgumentError.value(mnemonic, 'mnemonic', 'Unknown mnemonic'),
      };

  String get mnemonic;

  /// Output instructions are drawn at the right end of the rung.
  bool get isOutput;

  /// Canonical address text, the key of the symbol and description of the instruction.
  String get target;
}

/// Bit instructions: contacts (inputs) and coils (outputs).
sealed class BitInstruction extends Instruction {
  BitInstruction(String address) : address = BitAddress.parse(address);

  final BitAddress address;

  @override
  String get target => address.toString();
}

/// Examine if closed (normally open contact): passes power when the bit is 1.
final class Xic extends BitInstruction {
  Xic(super.address);
  @override
  String get mnemonic => 'XIC';
  @override
  bool get isOutput => false;
}

/// Examine if open (normally closed contact): passes power when the bit is 0.
final class Xio extends BitInstruction {
  Xio(super.address);
  @override
  String get mnemonic => 'XIO';
  @override
  bool get isOutput => false;
}

/// One-shot rising: passes power for a single scan on each false-to-true transition of the
/// rung; the bit stores the previous rung state.
final class Ons extends BitInstruction {
  Ons(super.address);
  @override
  String get mnemonic => 'ONS';
  @override
  bool get isOutput => false;
}

/// Output energize: bit follows rung power (non-retentive).
final class Ote extends BitInstruction {
  Ote(super.address);
  @override
  String get mnemonic => 'OTE';
  @override
  bool get isOutput => true;
}

/// Output latch: sets the bit when the rung is true (retentive).
final class Otl extends BitInstruction {
  Otl(super.address);
  @override
  String get mnemonic => 'OTL';
  @override
  bool get isOutput => true;
}

/// Output unlatch: clears the bit when the rung is true.
final class Otu extends BitInstruction {
  Otu(super.address);
  @override
  String get mnemonic => 'OTU';
  @override
  bool get isOutput => true;
}

/// Timer and counter instructions: they work on a `T4:n` / `C5:n` element and are outputs.
/// Power passes through unchanged.
sealed class BoxInstruction extends Instruction {
  BoxInstruction(String element, {BitFile? only})
      : element = ElementAddress.parse(element, only: only);

  final ElementAddress element;

  @override
  bool get isOutput => true;

  @override
  String get target => element.toString();
}

/// Timers: [preset] ticks of [timeBase] on a `T4:n` element.
sealed class TimerInstruction extends BoxInstruction {
  TimerInstruction(super.element, this.timeBase, this.preset) : super(only: BitFile.timer) {
    RangeError.checkValueInInterval(preset, 0, maxPreset, 'preset');
  }

  final TimeBase timeBase;
  final int preset;
}

/// Timer on-delay: times while the rung is true; DN when ACC reaches PRE.
final class Ton extends TimerInstruction {
  Ton(super.element, super.timeBase, super.preset);
  @override
  String get mnemonic => 'TON';
}

/// Timer off-delay: DN stays on for the preset time after the rung goes false.
final class Tof extends TimerInstruction {
  Tof(super.element, super.timeBase, super.preset);
  @override
  String get mnemonic => 'TOF';
}

/// Retentive timer on: like [Ton] but keeps ACC and DN when the rung is false (only [Res] clears it).
final class Rto extends TimerInstruction {
  Rto(super.element, super.timeBase, super.preset);
  @override
  String get mnemonic => 'RTO';
}

/// Counters: [preset] on a `C5:n` element.
sealed class CounterInstruction extends BoxInstruction {
  CounterInstruction(super.element, this.preset) : super(only: BitFile.counter) {
    RangeError.checkValueInInterval(preset, 0, maxPreset, 'preset');
  }

  final int preset;
}

/// Count up: ACC + 1 on each false-to-true transition of the rung.
final class Ctu extends CounterInstruction {
  Ctu(super.element, super.preset);
  @override
  String get mnemonic => 'CTU';
}

/// Count down: ACC - 1 on each false-to-true transition of the rung.
final class Ctd extends CounterInstruction {
  Ctd(super.element, super.preset);
  @override
  String get mnemonic => 'CTD';
}

/// Reset: when the rung is true, clears ACC and the status bits of a timer or counter.
final class Res extends BoxInstruction {
  Res(super.element);
  @override
  String get mnemonic => 'RES';
}

/// Data movement instructions: they write the destination word every scan while the rung
/// is true and are outputs. Power passes through unchanged.
sealed class WordInstruction extends Instruction {
  WordInstruction(String dest) : dest = WordAddress.parse(dest);

  final WordAddress dest;

  @override
  bool get isOutput => true;

  @override
  String get target => dest.toString();
}

/// Move: dest = source.
final class Mov extends WordInstruction {
  Mov(String source, super.dest) : source = Operand.parse(source);

  final Operand source;
  @override
  String get mnemonic => 'MOV';
}

/// Masked move: dest = (dest & ~mask) | (source & mask).
final class Mvm extends WordInstruction {
  Mvm(String source, String mask, super.dest)
      : source = Operand.parse(source),
        mask = Operand.parse(mask, mask: true);

  final Operand source;
  final Operand mask;
  @override
  String get mnemonic => 'MVM';
}

/// Swap bytes: dest = source with its high and low bytes exchanged.
final class Swp extends WordInstruction {
  Swp(String source, super.dest) : source = Operand.parse(source);

  final Operand source;
  @override
  String get mnemonic => 'SWP';
}

/// To BCD: dest = source (0..9999) as four BCD nibbles.
final class Tod extends WordInstruction {
  Tod(String source, super.dest) : source = Operand.parse(source);

  final Operand source;
  @override
  String get mnemonic => 'TOD';
}

/// From BCD: dest = decimal value of the four BCD nibbles of source.
final class Frd extends WordInstruction {
  Frd(String source, super.dest) : source = Operand.parse(source);

  final Operand source;
  @override
  String get mnemonic => 'FRD';
}

/// Clear: dest = 0.
final class Clr extends WordInstruction {
  Clr(super.dest);

  @override
  String get mnemonic => 'CLR';
}

/// Math instructions: they run every scan while the rung is true, write the destination word
/// (signed 16-bit, clamped on overflow) and update the arithmetic flags `S:0/0..3`. They are
/// outputs; power passes through unchanged.
sealed class MathInstruction extends WordInstruction {
  MathInstruction(super.dest);

  /// The source operands in the order RSLogix shows them (labels are the box's concern).
  List<Operand> get operands;
}

/// Two-source math instruction: dest = A op B.
sealed class BinaryMathInstruction extends MathInstruction {
  BinaryMathInstruction(String sourceA, String sourceB, super.dest)
      : sourceA = Operand.parse(sourceA),
        sourceB = Operand.parse(sourceB);

  final Operand sourceA;
  final Operand sourceB;

  @override
  List<Operand> get operands => [sourceA, sourceB];
}

/// Add: dest = A + B.
final class Add extends BinaryMathInstruction {
  Add(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'ADD';
}

/// Subtract: dest = A - B.
final class Sub extends BinaryMathInstruction {
  Sub(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'SUB';
}

/// Multiply: dest = A * B.
final class Mul extends BinaryMathInstruction {
  Mul(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'MUL';
}

/// Divide: dest = A / B, rounded to the nearest integer (halves away from zero).
final class Div extends BinaryMathInstruction {
  Div(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'DIV';
}

/// Modulo: dest = A % B (integer remainder); B = 0 sets overflow and gives 0.
final class Mod extends BinaryMathInstruction {
  Mod(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'MOD';
}

/// Exponentiation: dest = A ^ B.
final class Xpy extends BinaryMathInstruction {
  Xpy(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'XPY';
}

/// Single-source math instruction.
sealed class UnaryMathInstruction extends MathInstruction {
  UnaryMathInstruction(String source, super.dest) : source = Operand.parse(source);

  final Operand source;

  @override
  List<Operand> get operands => [source];
}

/// Negate: dest = -source.
final class Neg extends UnaryMathInstruction {
  Neg(super.source, super.dest);
  @override
  String get mnemonic => 'NEG';
}

/// Square root: dest = round(sqrt(|source|)); a negative source sets the carry flag.
final class Sqr extends UnaryMathInstruction {
  Sqr(super.source, super.dest);
  @override
  String get mnemonic => 'SQR';
}

/// Scale: dest = round(source * rate / 10000 + offset).
final class Scl extends MathInstruction {
  Scl(String source, String rate, String offset, super.dest)
      : source = Operand.parse(source),
        rate = Operand.parse(rate),
        offset = Operand.parse(offset);

  final Operand source;
  final Operand rate;
  final Operand offset;

  @override
  List<Operand> get operands => [source, rate, offset];
  @override
  String get mnemonic => 'SCL';
}

/// Bitwise logic instructions: they run every scan while the rung is true, write the
/// destination word and update the flags `S:0/0..3` (carry and overflow cleared). They are
/// outputs; power passes through unchanged.
sealed class LogicInstruction extends WordInstruction {
  LogicInstruction(super.dest);

  /// The source operands in the order RSLogix shows them (labels are the box's concern).
  List<Operand> get operands;
}

/// Two-source logic instruction: dest = A op B (the second source is the mask).
sealed class BinaryLogicInstruction extends LogicInstruction {
  BinaryLogicInstruction(String sourceA, String sourceB, super.dest)
      : sourceA = Operand.parse(sourceA),
        sourceB = Operand.parse(sourceB);

  final Operand sourceA;
  final Operand sourceB;

  @override
  List<Operand> get operands => [sourceA, sourceB];
}

/// Bitwise AND: dest = A & B.
final class And extends BinaryLogicInstruction {
  And(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'AND';
}

/// Bitwise OR: dest = A | B.
final class Or extends BinaryLogicInstruction {
  Or(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'OR';
}

/// Bitwise exclusive OR: dest = A ^ B.
final class Xor extends BinaryLogicInstruction {
  Xor(super.sourceA, super.sourceB, super.dest);
  @override
  String get mnemonic => 'XOR';
}

/// Bitwise NOT (one's complement): dest = ~source.
final class Not extends LogicInstruction {
  Not(String source, super.dest) : source = Operand.parse(source);

  final Operand source;

  @override
  List<Operand> get operands => [source];
  @override
  String get mnemonic => 'NOT';
}

/// Compare instructions: input (condition) instructions that pass power when the
/// comparison of the signed 16-bit values of [sourceA] and [sourceB] holds. They write nothing.
sealed class CompareInstruction extends Instruction {
  CompareInstruction(String sourceA, String sourceB)
      : sourceA = WordAddress.parse(sourceA),
        sourceB = Operand.parse(sourceB);

  final WordAddress sourceA;
  final Operand sourceB;

  @override
  bool get isOutput => false;

  @override
  String get target => sourceA.toString();

  /// The comparison of [a] and [b].
  bool compare(int a, int b);

  /// Whether the condition holds, reading each operand through [read].
  bool holds(int Function(Operand) read) => compare(read(sourceA), read(sourceB));
}

/// Equal: A == B.
final class Equ extends CompareInstruction {
  Equ(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'EQU';
  @override
  bool compare(int a, int b) => a == b;
}

/// Not equal: A != B.
final class Neq extends CompareInstruction {
  Neq(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'NEQ';
  @override
  bool compare(int a, int b) => a != b;
}

/// Less than: A < B.
final class Les extends CompareInstruction {
  Les(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'LES';
  @override
  bool compare(int a, int b) => a < b;
}

/// Less than or equal: A <= B.
final class Leq extends CompareInstruction {
  Leq(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'LEQ';
  @override
  bool compare(int a, int b) => a <= b;
}

/// Greater than: A > B.
final class Grt extends CompareInstruction {
  Grt(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'GRT';
  @override
  bool compare(int a, int b) => a > b;
}

/// Greater than or equal: A >= B.
final class Geq extends CompareInstruction {
  Geq(super.sourceA, super.sourceB);
  @override
  String get mnemonic => 'GEQ';
  @override
  bool compare(int a, int b) => a >= b;
}

/// Limit test (input instruction): with low <= high it is true when low <= test <= high;
/// with low > high it is true when test >= low or test <= high. Each operand is a word
/// address or a constant.
final class Lim extends Instruction {
  Lim(String low, String test, String high)
      : low = Operand.parse(low),
        test = Operand.parse(test),
        high = Operand.parse(high);

  final Operand low;
  final Operand test;
  final Operand high;

  @override
  String get mnemonic => 'LIM';
  @override
  bool get isOutput => false;
  @override
  String get target => test.toString();

  /// Whether the test value is within the limits, reading each operand through [read].
  bool holds(int Function(Operand) read) {
    final lo = read(low);
    final t = read(test);
    final hi = read(high);
    return lo <= hi ? lo <= t && t <= hi : t >= lo || t <= hi;
  }
}

/// Parallel branch: power out is the OR of every path.
final class Branch extends RungElement {
  const Branch(this.paths);

  final List<List<RungElement>> paths;
}

class Rung {
  const Rung(this.elements, {this.comment = '', this.title = ''});

  final List<RungElement> elements;
  final String comment;

  /// Page title shown above the rung comment (empty = none).
  final String title;

  Rung copyWith({List<RungElement>? elements, String? comment, String? title}) => Rung(
        elements ?? this.elements,
        comment: comment ?? this.comment,
        title: title ?? this.title,
      );
}

class Program {
  const Program(this.rungs, {this.symbols = const {}, this.descriptions = const {}});

  final List<Rung> rungs;

  /// Symbol (short name) keyed by canonical address (e.g. `I:0/0` → "B1 Liga").
  final Map<String, String> symbols;

  /// Multi-line address description keyed by canonical address (e.g. `I:0/0` → "Botão liga\nmotor M1").
  final Map<String, String> descriptions;

  Program copyWith({
    List<Rung>? rungs,
    Map<String, String>? symbols,
    Map<String, String>? descriptions,
  }) =>
      Program(
        rungs ?? this.rungs,
        symbols: symbols ?? this.symbols,
        descriptions: descriptions ?? this.descriptions,
      );

  String? symbolFor(BitAddress a) => symbols[a.toString()];

  String? descriptionFor(BitAddress a) => descriptions[a.toString()];

  /// Symbol of the address an instruction works on (bit or `T4:n` / `C5:n` element).
  String? symbolOf(Instruction i) => symbols[i.target];

  String? descriptionOf(Instruction i) => descriptions[i.target];
}
