import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService.instance;

  bool _isPhoneAuth = false;
  bool _isOtpSent = false;
  String _verificationId = '';

  Future<void> _handleLogin() async {
    if (_emailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty) {
      try {
        final result = await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        if (result != null && mounted) {
          final userData = await _authService.getUserData();
          final userType = userData?['userType'] ?? 'client';
          final userName = userData?['fullName'] ??
              userData?['name'] ??
              result.user?.displayName ??
              'Utilisateur';
          final userEmail = result.user?.email ?? '';

          // Sauvegarder les données utilisateur dans SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_user', userEmail);
          await prefs.setString('current_user_type', userType);
          await prefs.setString('username_$userEmail', userName);

          print('✅ Utilisateur connecté: $userEmail ($userType) - $userName');

          // Initialiser FCM pour l'utilisateur connecté
          await _authService.initializeMessaging();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connexion réussie! Bienvenue $userName'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email ou mot de passe incorrect'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _handlePhoneAuth() async {
    if (_phoneController.text.isNotEmpty) {
      try {
        await _authService.verifyPhoneNumber(
          _phoneController.text.trim(),
          (PhoneAuthCredential credential) async {
            // Auto-résolution
            final result =
                await _authService.signInWithPhoneCredential(credential);
            if (result != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Connexion par téléphone réussie!'),
                  backgroundColor: Colors.green,
                ),
              );
              context.go('/home');
            }
          },
          (FirebaseAuthException e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: ${e.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          (String verificationId, int? resendToken) {
            setState(() {
              _verificationId = verificationId;
              _isOtpSent = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code de vérification envoyé!'),
                  backgroundColor: Colors.blue,
                ),
              );
            }
          },
          (String verificationId) {
            setState(() {
              _verificationId = verificationId;
            });
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.isNotEmpty && _verificationId.isNotEmpty) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId,
          smsCode: _otpController.text.trim(),
        );

        final result = await _authService.signInWithPhoneCredential(credential);
        if (result != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion par téléphone réussie!'),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/home');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Code incorrect: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVisitorMode() async {
    try {
      print('🔓 DÉCONNEXION COMPLÈTE - Mode visiteur activé');

      // ÉTAPE 1: Déconnexion Firebase complète
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        print('🔥 Firebase Auth déconnecté');
      }

      // ÉTAPE 2: Nettoyage complet des SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Nettoie TOUT
      print('🧹 SharedPreferences nettoyées complètement');

      // ÉTAPE 3: Configuration du mode visiteur pur
      await prefs.setString('current_user', 'Visiteur');
      await prefs.setString('current_user_type', 'visiteur');
      print('👁️ Mode visiteur configuré - Aucune session utilisateur');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Mode visiteur activé - Vous pouvez explorer sans réserver'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      print('❌ Erreur activation mode visiteur: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 64 : 24,
              vertical: 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.sports_soccer,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'BookFoot237',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Réservez votre terrain de football',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Login Form
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Connexion',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E88E5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),

                      // Toggle between email and phone auth
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isPhoneAuth = false),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: !_isPhoneAuth
                                    ? const Color(0xFF1E88E5)
                                    : null,
                                foregroundColor: !_isPhoneAuth
                                    ? Colors.white
                                    : const Color(0xFF1E88E5),
                              ),
                              child: const Text('Email'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  setState(() => _isPhoneAuth = true),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isPhoneAuth
                                    ? const Color(0xFF1E88E5)
                                    : null,
                                foregroundColor: _isPhoneAuth
                                    ? Colors.white
                                    : const Color(0xFF1E88E5),
                              ),
                              child: const Text('Téléphone'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Email auth fields
                      if (!_isPhoneAuth) ...[
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ],

                      // Phone auth fields
                      if (_isPhoneAuth) ...[
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Numéro de téléphone',
                            hintText: '+237612345678',
                            prefixIcon: const Icon(Icons.phone),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Code de vérification',
                              hintText: '123456',
                              prefixIcon: const Icon(Icons.sms),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 24),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_isPhoneAuth) {
                              if (_isOtpSent) {
                                _verifyOtp();
                              } else {
                                _handlePhoneAuth();
                              }
                            } else {
                              _handleLogin();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isPhoneAuth
                                ? (_isOtpSent
                                    ? 'Vérifier le code'
                                    : 'Envoyer le code')
                                : 'Se connecter',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.go('/register'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E88E5),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Créer un compte',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visitor mode button
                      TextButton(
                        onPressed: _handleVisitorMode,
                        child: const Text(
                          '👁️ Continuer en tant que visiteur',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}