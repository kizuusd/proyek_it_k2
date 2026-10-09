import 'package:flutter/widgets.dart';
import 'screens/tracking_sales/fr01_login_screen.dart';
import 'screens/tracking_sales/home_dashboard_screen.dart';

// We use name route
// All our routes will be available here
final Map<String, WidgetBuilder> routes = {
  '/login': (context) => const FR01LoginScreen(),
  '/dashboard': (context) => const HomeDashboardScreen(),
};
