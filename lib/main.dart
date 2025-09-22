import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Core app
import 'core/app.dart';

// Services
import 'services/firebase_auth_service.dart';
import 'services/supabase_storage_service.dart';
import 'services/app_lifecycle_service.dart';

// Configuration
import 'config/supabase_config.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  // Initialize Supabase buckets
  await SupabaseStorageService.initializeBuckets();

  // Initialize French localization
  await initializeDateFormatting('fr_FR');

  // Initialize Firebase Cloud Messaging
  await FirebaseAuthService.instance.initializeMessaging();

  // Initialize app lifecycle service to prevent auto-destruction
  AppLifecycleService().initialize();

  // Run the app
  runApp(const BookFootApp());
}