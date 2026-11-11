import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The ONE place that maps ladder symbols to SVG files. The rung view and the instruction toolbar both
/// draw symbols through [ladderSymbol], so replacing a file in `assets/ladder/` (or editing
/// this map) changes the symbol everywhere. Colors come from the theme, not from the file.
abstract final class LadderAssets {
  /// Key of the branch tool (it is not an instruction mnemonic).
  static const branch = 'BRANCH';

  /// Key of the new-rung tool (it is not an instruction mnemonic).
  static const rung = 'RUNG';

  static const _paths = {
    'XIC': 'assets/ladder/xic.svg',
    'XIO': 'assets/ladder/xio.svg',
    'OTE': 'assets/ladder/ote.svg',
    'OTL': 'assets/ladder/otl.svg',
    'OTU': 'assets/ladder/otu.svg',
    'TON': 'assets/ladder/ton.svg',
    'TOF': 'assets/ladder/tof.svg',
    'RTO': 'assets/ladder/rto.svg',
    'CTU': 'assets/ladder/ctu.svg',
    'CTD': 'assets/ladder/ctd.svg',
    'RES': 'assets/ladder/res.svg',
    'MOV': 'assets/ladder/mov.svg',
    'MVM': 'assets/ladder/mvm.svg',
    'CLR': 'assets/ladder/clr.svg',
    'EQU': 'assets/ladder/equ.svg',
    'NEQ': 'assets/ladder/neq.svg',
    'LES': 'assets/ladder/les.svg',
    'LEQ': 'assets/ladder/leq.svg',
    'GRT': 'assets/ladder/grt.svg',
    'GEQ': 'assets/ladder/geq.svg',
    'LIM': 'assets/ladder/lim.svg',
    'ADD': 'assets/ladder/add.svg',
    'SUB': 'assets/ladder/sub.svg',
    'MUL': 'assets/ladder/mul.svg',
    'DIV': 'assets/ladder/div.svg',
    'NEG': 'assets/ladder/neg.svg',
    'SQR': 'assets/ladder/sqr.svg',
    'SCL': 'assets/ladder/scl.svg',
    'AND': 'assets/ladder/and.svg',
    'OR': 'assets/ladder/or.svg',
    'XOR': 'assets/ladder/xor.svg',
    'NOT': 'assets/ladder/not.svg',
    'MOD': 'assets/ladder/mod.svg',
    'XPY': 'assets/ladder/xpy.svg',
    'SWP': 'assets/ladder/swp.svg',
    'TOD': 'assets/ladder/tod.svg',
    'FRD': 'assets/ladder/frd.svg',
    'ONS': 'assets/ladder/ons.svg',
    branch: 'assets/ladder/branch.svg',
    rung: 'assets/ladder/rung.svg',
  };

  static String pathFor(String key) => _paths[key]!;
}

/// Draws the symbol of a mnemonic (or a tool key from [LadderAssets]) tinted with [color].
Widget ladderSymbol(String key, {required Color color, double? width, double? height}) =>
    SvgPicture.asset(
      LadderAssets.pathFor(key),
      width: width,
      height: height,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
