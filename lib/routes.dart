import 'package:flutter/widgets.dart';
import 'screens/tracking_sales/fr01_login_screen.dart';
import 'screens/tracking_sales/home_dashboard_screen.dart';

// Definisi route aplikasi Tracking Sales CV Maju Bersama
final Map<String, WidgetBuilder> routes = {
  '/login': (context) => const FR01LoginScreen(),
  '/dashboard': (context) => const HomeDashboardScreen(),
};
