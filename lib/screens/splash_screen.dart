import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../constants/api_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/child_mode_provider.dart';
import 'admin_home_screen.dart';
import 'child/child_enrollment_screen.dart';
import 'child/child_home_screen.dart';
import 'login_screen.dart';
import 'mode_selection_screen.dart';
import 'parent_home_screen.dart';

/// Splash screen that checks for chosen App Mode and existing JWT sessions upon app initialization.
class SplashScreen extends StatefulWidget {
  final FlutterSecureStorage secureStorage;

  const SplashScreen({
    super.key,
    this.secureStorage = const FlutterSecureStorage(),
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final appMode = await widget.secureStorage.read(key: ApiConstants.appModeStorageKey);

    if (!mounted) return;

    if (appMode == null || appMode.isEmpty) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ModeSelectionScreen(secureStorage: widget.secureStorage),
        ),
      );
      return;
    }

    if (appMode == 'child') {
      final childProvider = context.read<ChildModeProvider>();
      await childProvider.checkChildSession(autoStartSync: true);

      if (!mounted) return;

      if (childProvider.isEnrolled) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChildHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ChildEnrollmentScreen()),
        );
      }
      return;
    }

    // Default: Parent Mode
    final authProvider = context.read<AuthProvider>();
    await authProvider.checkSession();

    if (!mounted) return;

    if (authProvider.isAuthenticated) {
      final user = authProvider.user!;
      if (user.isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ParentHomeScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 64,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Parental Control',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đang kiểm tra phiên làm việc...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

