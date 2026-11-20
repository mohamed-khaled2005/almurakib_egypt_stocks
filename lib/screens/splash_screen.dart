import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/favorites_service.dart';
import '../providers/app_manager_provider.dart';
import '../widgets/app_loading_widget.dart';
import 'app_shell_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.15, 1.0)),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startFlow());
  }

  Future<void> _startFlow() async {
    await FavoritesService.init();
    await _waitForAppManager();

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const AppShellScreen(),
      ),
    );
  }

  Future<void> _waitForAppManager() async {
    final manager = context.read<AppManagerProvider>();
    while (!manager.initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: const AppLoadingWidget(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
