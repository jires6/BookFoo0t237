import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/email_confirmation_page.dart';
import '../pages/auth/registration_success_page.dart';
import '../pages/home/home_page.dart';

class BookFootApp extends StatelessWidget {
  const BookFootApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BookFoot237',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      routerConfig: GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterPage(),
          ),
          GoRoute(
            path: '/email-confirmation',
            builder: (context, state) => const EmailConfirmationPage(),
          ),
          GoRoute(
            path: '/registration-success',
            builder: (context, state) => const RegistrationSuccessPage(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
    );
  }
}