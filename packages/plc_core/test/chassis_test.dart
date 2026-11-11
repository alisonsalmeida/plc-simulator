import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

void main() {
  group('catalog and types', () {
    test('chassis types have 4, 7, 10 and 13 slots', () {
      expect(ChassisType.values.map((t) => t.slotCount), [4, 7, 10, 13]);
    });

    test('catalog lists the mountable modules and finds them by number', () {
      expect(ModuleCatalog.all, isNotEmpty);
      expect(ModuleCatalog.all, isNot(contains(ModuleCatalog.empty)));
      expect(ModuleCatalog.find('1746-OB16'), ModuleCatalog.ob16);
      expect(ModuleCatalog.find('EMPTY'), ModuleCatalog.empty);
      expect(ModuleCatalog.find('nope'), isNull);
    });
  });

  group('default config', () {
    final c = ChassisConfig.defaultConfig();

    test('is a 10-slot rack with CPU, NI4 and NO2', () {
      expect(c.type, ChassisType.a10);
      expect(c.slots.length, 10);
      expect(c.moduleAt(0), ModuleCatalog.emu1400);
      expect(c.moduleAt(1), ModuleCatalog.ni4);
      expect(c.moduleAt(2), ModuleCatalog.no2);
      expect(c.moduleAt(3), ModuleCatalog.empty);
    });

    test('accepts the legacy addresses', () {
      for (final t in ['I:0/0', 'O:0/15', 'I:1.0', 'I:1.3', 'O:2.0', 'O:2.1']) {
        expect(c.validateAddressString(t), isNull, reason: t);
      }
    });
  });

  group('validation', () {
    test('empty slot rejects O:3/0', () {
      expect(ChassisConfig.defaultConfig().validateAddressString('O:3/0'), contains('vazio'));
    });

    test('OB16 in slot 1', () {
      final c = ChassisConfig.defaultConfig().setSlot(1, ModuleCatalog.ob16);
      expect(c.validateAddressString('I:1/0'), isNotNull);
      expect(c.validateAddressString('O:1/0'), isNull);
      expect(c.validateAddressString('O:1/15'), isNull);
      expect(c.validateAddressString('O:1/16'), isNotNull);
    });

    test('IB16 in slot 1', () {
      final c = ChassisConfig.defaultConfig().setSlot(1, ModuleCatalog.ib16);
      expect(c.validateAddressString('I:1/0'), isNull);
      expect(c.validateAddressString('O:1/0'), isNotNull);
      expect(c.validateAddressString('I:1.0'), isNotNull);
    });

    test('slot beyond a 4-slot chassis is rejected', () {
      final c = ChassisConfig.defaultConfig().changeType(ChassisType.a4);
      expect(c.validateAddressString('I:12/0'), isNotNull);
    });

    test('garbage is rejected', () {
      expect(ChassisConfig.defaultConfig().validateAddressString('xyz'), isNotNull);
    });

    test('slot 0 only takes a CPU and cannot be cleared', () {
      final c = ChassisConfig.defaultConfig();
      expect(() => c.setSlot(0, ModuleCatalog.ib16), throwsArgumentError);
      expect(() => c.setSlot(1, ModuleCatalog.slc503), throwsArgumentError);
      expect(() => c.clearSlot(0), throwsArgumentError);
      expect(c.clearSlot(1).moduleAt(1), ModuleCatalog.empty);
    });

    test('changeType keeps modules and pads with empty slots', () {
      final c = ChassisConfig.defaultConfig().changeType(ChassisType.a13);
      expect(c.slots.length, 13);
      expect(c.moduleAt(1), ModuleCatalog.ni4);
      expect(c.moduleAt(12), ModuleCatalog.empty);
    });
  });

  group('JSON', () {
    test('chassis roundtrip', () {
      final c = ChassisConfig.defaultConfig().setSlot(3, ModuleCatalog.ob16);
      final back = ChassisConfig.fromJson(c.toJson());
      expect(back.type, c.type);
      expect([for (final m in back.slots) m.catalogNumber], [for (final m in c.slots) m.catalogNumber]);
    });

    test('program roundtrip keeps the chassis and legacy JSON gets the default', () {
      final p = const Program([]).copyWith(
        chassis: ChassisConfig.defaultConfig().setSlot(1, ModuleCatalog.ob16),
      );
      final json = programToJson(p);
      expect(programFromJson(json).chassis.moduleAt(1), ModuleCatalog.ob16);
      json.remove('chassis');
      expect(programFromJson(json).chassis.moduleAt(1), ModuleCatalog.ni4);
    });
  });
}
