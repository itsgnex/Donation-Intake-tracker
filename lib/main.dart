import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// entry screens
import 'screens/home_page.dart';
import 'screens/login/login.dart';

// login screens
import 'screens/login/admin_login.dart';
import 'screens/login/store_login.dart';
import 'screens/login/volunteer_login.dart';

// dashboards
import 'screens/dashboard/admin_dashboard.dart';
import 'screens/dashboard/store_dashboard.dart';
import 'screens/dashboard/volunteer_dashboard.dart';

// ✅ store registration screen (NOTE: file name is store_register.dart)
import 'screens/regestration/store_register.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FoodLink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      // start on the home screen
      initialRoute: 'home',

      routes: {
        // entry
        'home': (context) => const HomePage(),
        'login': (context) => const MyLogin(),

        // logins
        'adminLogin': (context) => const AdminLoginPage(),
        'storeLogin': (context) => const StoreLoginPage(),
        'volunteerLogin': (context) => const VolunteerLoginPage(),

        // dashboards
        'adminDashboard': (context) => const AdminDashboard(),
        'storeDashboard': (context) => const StoreDashboard(),
        'volunteerDashboard': (context) => const VolunteerDashboard(),

        // ✅ store registration
        'storeRegister': (context) => const StoreRegisterPage(),
      },
    );
  }
}
