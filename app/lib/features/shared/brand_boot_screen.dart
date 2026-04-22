import 'package:flutter/material.dart';
import '../../core/theme/brand_colors.dart';

/// Full-screen dark scaffold shown during auth rehydration or any pre-route
/// boot state. The logo is tagged `brand-mark` so it Hero-animates to the
/// first real AppBar when hand-off happens.
class BrandBootScreen extends StatelessWidget {
  const BrandBootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.darkBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'brand-mark',
              child: Image.asset(
                'assets/icon/splash_logo.png',
                width: 280,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: BrandColors.cyan400.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
