import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pos_app/navigation/nav_widgets.dart';

class PowerModal extends StatelessWidget {
  const PowerModal({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: context.navSidebarBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Exit application",
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Are you sure you want to exit the application?",
              style: TextStyle(color: context.navMuted, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _PowerOptionCard(
                  icon: Icons.power_settings_new,
                  label: "Exit application",
                  iconColor: cs.onSurface,
                  onTap: () => exit(0),
                ),
                _PowerOptionCard(
                  icon: Icons.refresh,
                  label: "Restart application",
                  iconColor: cs.onSurface,
                  onTap: () async {
                    try {
                      await Process.run(Platform.resolvedExecutable, []);
                      exit(0);
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
                _PowerOptionCard(
                  icon: Icons.power_settings_new,
                  label: "Turn off PC",
                  iconColor: Colors.redAccent,
                  textColor: Colors.redAccent,
                  onTap: () async {
                    try {
                      if (Platform.isWindows) {
                        await Process.run('shutdown', ['/s', '/t', '0']);
                      } else if (Platform.isMacOS) {
                        await Process.run('osascript', [
                          '-e',
                          'tell app "System Events" to shut down',
                        ]);
                      } else if (Platform.isLinux) {
                        await Process.run('systemctl', ['poweroff']);
                      }
                    } catch (e) {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: cs.onSurface),
              label: Text("Cancel", style: TextStyle(color: cs.onSurface)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.navDivider),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerOptionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _PowerOptionCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.textColor,
  });

  @override
  State<_PowerOptionCard> createState() => _PowerOptionCardState();
}

class _PowerOptionCardState extends State<_PowerOptionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: _hovered ? context.navHover : Colors.transparent,
            border: Border.all(
              color: _hovered ? context.navDivider : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 54, color: widget.iconColor),
              const SizedBox(height: 16),
              // Flexible + ellipsis so a larger font scale can't push the label
              // past the fixed 150px card height (vertical overflow).
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.textColor ?? Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
