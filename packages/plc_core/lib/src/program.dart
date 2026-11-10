import 'address.dart';

/// Anything that can sit on a rung: an instruction or a parallel branch.
sealed class RungElement {
  const RungElement();
}

/// Bit instructions: contacts (inputs) and coils (outputs).
sealed class Instruction extends RungElement {
  Instruction(String address) : address = BitAddress.parse(address);

  /// Builds an instruction from its SLC 500 [mnemonic] (XIC, XIO, OTE, OTL, OTU).
  ///
  /// Throws [ArgumentError] for an unknown mnemonic and [FormatException] for a bad address.
  factory Instruction.create(String mnemonic, String address) =>
      switch (mnemonic.toUpperCase()) {
        'XIC' => Xic(address),
        'XIO' => Xio(address),
        'OTE' => Ote(address),
        'OTL' => Otl(address),
        'OTU' => Otu(address),
        _ => throw ArgumentError.value(mnemonic, 'mnemonic', 'Unknown mnemonic'),
      };

  final BitAddress address;

  String get mnemonic;

  /// Output instructions are drawn at the right end of the rung.
  bool get isOutput;
}

/// Examine if closed (normally open contact): passes power when the bit is 1.
final class Xic extends Instruction {
  Xic(super.address);
  @override
  String get mnemonic => 'XIC';
  @override
  bool get isOutput => false;
}

/// Examine if open (normally closed contact): passes power when the bit is 0.
final class Xio extends Instruction {
  Xio(super.address);
  @override
  String get mnemonic => 'XIO';
  @override
  bool get isOutput => false;
}

/// Output energize: bit follows rung power (non-retentive).
final class Ote extends Instruction {
  Ote(super.address);
  @override
  String get mnemonic => 'OTE';
  @override
  bool get isOutput => true;
}

/// Output latch: sets the bit when the rung is true (retentive).
final class Otl extends Instruction {
  Otl(super.address);
  @override
  String get mnemonic => 'OTL';
  @override
  bool get isOutput => true;
}

/// Output unlatch: clears the bit when the rung is true.
final class Otu extends Instruction {
  Otu(super.address);
  @override
  String get mnemonic => 'OTU';
  @override
  bool get isOutput => true;
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
}
