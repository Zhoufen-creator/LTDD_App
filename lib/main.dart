import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'constants/api_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/child_mode_provider.dart';
import 'providers/children_provider.dart';
import 'providers/devices_provider.dart';
import 'providers/monitoring_rules_provider.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/battery_service.dart';
import 'services/biometric_service.dart';
import 'services/child_service.dart';
import 'services/device_service.dart';
import 'services/location_service.dart';
import 'services/monitoring_rule_service.dart';
import 'services/safety_advisor_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate foundational storage and API services with secure JWT resolution
  const secureStorage = FlutterSecureStorage();
  final apiService = ApiService(
    tokenGetter: () => secureStorage.read(key: ApiConstants.tokenStorageKey),
  );
  final authService = AuthService(
    apiService: apiService,
    secureStorage: secureStorage,
  );
  final childService = ChildService(apiService: apiService);
  final deviceService = DeviceService(apiService: apiService);
  final locationService = LocationService(apiService: apiService);
  final monitoringRuleService = MonitoringRuleService(apiService: apiService);
  final safetyAdvisorService = SafetyAdvisorService(apiService: apiService);
  final batteryService = BatteryService();
  final biometricService = BiometricService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        Provider<AuthService>.value(value: authService),
        Provider<ChildService>.value(value: childService),
        Provider<DeviceService>.value(value: deviceService),
        Provider<LocationService>.value(value: locationService),
        Provider<MonitoringRuleService>.value(value: monitoringRuleService),
        Provider<SafetyAdvisorService>.value(value: safetyAdvisorService),
        Provider<BatteryService>.value(value: batteryService),
        Provider<BiometricService>.value(value: biometricService),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            authService: authService,
            biometricService: biometricService,
          ),
        ),
        ChangeNotifierProvider<ChildrenProvider>(
          create: (_) => ChildrenProvider(childService: childService),
        ),
        ChangeNotifierProvider<DevicesProvider>(
          create: (_) => DevicesProvider(deviceService: deviceService),
        ),
        ChangeNotifierProvider<MonitoringRulesProvider>(
          create: (_) => MonitoringRulesProvider(ruleService: monitoringRuleService),
        ),
        ChangeNotifierProvider<ChildModeProvider>(
          create: (_) => ChildModeProvider(
            deviceService: deviceService,
            locationService: locationService,
            batteryService: batteryService,
            secureStorage: secureStorage,
          ),
        ),
      ],
      child: const ParentalControlApp(),
    ),
  );
}

/// Root widget of the Parental Control application configuring Material 3 theme and routing.
class ParentalControlApp extends StatelessWidget {
  const ParentalControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parental Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3A8A), // Professional Indigo/Navy
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
