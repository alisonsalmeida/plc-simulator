import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'pages/editor/editor.page.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ProviderScope(child: PlcSimulatorApp()));

class PlcSimulatorApp extends StatelessWidget {
  const PlcSimulatorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Simulador CLP',
        theme: buildAppTheme(),
        debugShowCheckedModeBanner: false,
        home: const EditorPage(),
      );
}
