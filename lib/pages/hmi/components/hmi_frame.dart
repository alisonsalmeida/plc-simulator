import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/hmi.controller.dart';
import '../../../models/hmi_state.model.dart';
import 'hmi_bar.dart';
import 'hmi_button.dart';
import 'hmi_display.dart';
import 'hmi_lamp.dart';
import 'hmi_toggle.dart';
import 'hmi_widget_dialog.dart';

/// A widget on the canvas: its label doubles as the drag handle, and a right-click (or a
/// long-press on the handle) opens the Editar / Excluir menu.
class HmiFrame extends ConsumerWidget {
  const HmiFrame({super.key, required this.widget});

  final HmiWidget widget;

  Widget _body() => switch (widget.kind) {
        HmiKind.button => HmiButton(widget: widget),
        HmiKind.toggle => HmiToggle(widget: widget),
        HmiKind.lamp => HmiLamp(widget: widget),
        HmiKind.display => HmiDisplay(widget: widget),
        HmiKind.bar => HmiBar(widget: widget),
      };

  Future<void> _menu(BuildContext context, WidgetRef ref, Offset at) async {
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: const [
        PopupMenuItem(value: 'edit', child: Text('Editar')),
        PopupMenuItem(value: 'delete', child: Text('Excluir')),
      ],
    );
    if (!context.mounted) return;
    if (choice == 'delete') ref.read(hmiProvider.notifier).remove(widget.id);
    if (choice == 'edit') {
      await showHmiWidgetDialog(
        context,
        kind: widget.kind,
        initial: widget,
        submit: (address, label, min, max) =>
            ref.read(hmiProvider.notifier).update(widget.id, address, label: label, min: min, max: max),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Positioned(
        left: widget.x,
        top: widget.y,
        child: GestureDetector(
          onSecondaryTapUp: (d) => _menu(context, ref, d.globalPosition),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                MouseRegion(
                  cursor: SystemMouseCursors.move,
                  child: GestureDetector(
                    key: ValueKey('hmi-handle-${widget.id}'),
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => ref
                        .read(hmiProvider.notifier)
                        .move(widget.id, widget.x + d.delta.dx, widget.y + d.delta.dy),
                    onLongPressStart: (d) => _menu(context, ref, d.globalPosition),
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 64),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      alignment: Alignment.center,
                      child: Text(widget.label, style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _body(),
              ]),
            ),
          ),
        ),
      );
}
