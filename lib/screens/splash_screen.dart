import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/tokens.dart';
import '../providers/core_providers.dart';
import '../widgets/app_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bar =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.wait<void>([
      ref.read(authProvider.notifier).init(),
      Future<void>.delayed(const Duration(milliseconds: 1800)),
    ]);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final logoW = w * 0.56 < 220 ? w * 0.56 : 220.0;
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: logoW,
                height: logoW,
                padding: EdgeInsets.all(logoW * 0.1),
                decoration: BoxDecoration(
                  color: T.glass2,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: T.glassEdge),
                  boxShadow: T.shadow,
                ),
                child: Image.asset('assets/images/auzify-logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 22),
              const Text('Streaming musik dengan lirik',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: T.ink2)),
              const SizedBox(height: 6),
              const Text('Menyiapkan musikmu…',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: T.ink3)),
              const SizedBox(height: 18),
              SizedBox(
                width: 96,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: ColoredBox(color: T.accentSoft)),
                      AnimatedBuilder(
                        animation: _bar,
                        builder: (_, __) => Positioned(
                          left: -40 + (96 + 40) * T.ease.transform(_bar.value),
                          width: 40,
                          top: 0,
                          bottom: 0,
                          child: const ColoredBox(color: T.accent),
                        ),
                      ),
                    ],
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
