import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/settings/settings_cubit.dart';
import '../../../core/settings/settings_store.dart';

/// Accessibility section — text scale (four presets) and reduce motion.
///
/// The text scale is consumed by a `MediaQuery` override in `main.dart`
/// so every `Text` widget scales uniformly. Reduce motion is honoured
/// by animation-heavy widgets (cue overlays, feed transitions) which
/// short-circuit their duration when the flag is set.
class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    return Scaffold(
      appBar: AppBar(title: const Text('Accessibility')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            title: Text(
              'Text size',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: const Text(
              'Applies across all screens.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: SettingsStore.allowedTextScales
                  .map(
                    (scale) => ChoiceChip(
                      key: Key('settings.a11y.textScale.$scale'),
                      label: Text(_labelFor(scale)),
                      selected: state.textScaleMultiplier == scale,
                      onSelected: (picked) {
                        if (!picked) return;
                        cubit.setTextScaleMultiplier(scale);
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          SwitchListTile(
            key: const Key('settings.a11y.reduceMotion'),
            secondary: const Icon(Icons.motion_photos_off_outlined),
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Minimises animations and transitions.',
            ),
            value: state.reduceMotion,
            onChanged: cubit.setReduceMotion,
          ),
          const Divider(),
          // Slice P7a — biometric unlock is live. Flipping the toggle
          // on probes `canCheckBiometrics` + `isDeviceSupported`; if
          // the device can't, we surface a snackbar and leave the
          // preference off. Cold-start gating happens in
          // `core/auth/biometric_gate.dart`.
          SwitchListTile(
            key: const Key('settings.a11y.biometricUnlock'),
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric unlock'),
            subtitle: const Text(
              'Require fingerprint / face unlock when reopening the app.',
            ),
            value: state.biometricUnlock,
            onChanged: (desired) async {
              if (desired) {
                final auth = LocalAuthentication();
                bool canCheck = false;
                bool supported = false;
                try {
                  canCheck = await auth.canCheckBiometrics;
                  supported = await auth.isDeviceSupported();
                } on PlatformException {
                  canCheck = false;
                }
                if (!context.mounted) return;
                if (!canCheck || !supported) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No biometrics available on this device.',
                      ),
                    ),
                  );
                  return;
                }
              }
              cubit.setBiometricUnlock(desired);
            },
          ),
        ],
      ),
    );
  }

  String _labelFor(double scale) {
    if (scale == 0.9) return 'Small';
    if (scale == 1.0) return 'Default';
    if (scale == 1.15) return 'Large';
    if (scale == 1.3) return 'Extra large';
    return scale.toStringAsFixed(2);
  }
}
