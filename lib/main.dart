import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReservationRequest {
  final String id;
  final String stadeId;
  final String stadeNom;
  final String clientNom;
  final String clientEmail;
  final DateTime dateReservation;
  final String heureDebut;
  final String heureFin;
  final String raison;
  final String statut;
  final DateTime dateCreation;
  
  ReservationRequest({
    required this.id,
    required this.stadeId,
    required this.stadeNom,
    required this.clientNom,
    required this.clientEmail,
    required this.dateReservation,
    required this.heureDebut,
    required this.heureFin,
    required this.raison,
    required this.statut,
    required this.dateCreation,
  });
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'stadeId': stadeId,
    'stadeNom': stadeNom,
    'clientNom': clientNom,
    'clientEmail': clientEmail,
    'dateReservation': dateReservation.toIso8601String(),
    'heureDebut': heureDebut,
    'heureFin': heureFin,
    'raison': raison,
    'statut': statut,
    'dateCreation': dateCreation.toIso8601String(),
  };
  
  static ReservationRequest fromJson(Map<String, dynamic> json) => ReservationRequest(
    id: json['id'],
    stadeId: json['stadeId'],
    stadeNom: json['stadeNom'],
    clientNom: json['clientNom'],
    clientEmail: json['clientEmail'],
    dateReservation: DateTime.parse(json['dateReservation']),
    heureDebut: json['heureDebut'],
    heureFin: json['heureFin'],
    raison: json['raison'],
    statut: json['statut'],
    dateCreation: DateTime.parse(json['dateCreation']),
  );
}

void main() {
  runApp(const BookFootApp());
}

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
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    if (_emailController.text.isNotEmpty && _passwordController.text.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final savedPassword = prefs.getString('user_${_emailController.text}');
        
        if (savedPassword == _passwordController.text) {
          await prefs.setString('current_user', _emailController.text);
          final userType = prefs.getString('usertype_${_emailController.text}') ?? 'client';
          await prefs.setString('current_user_type', userType);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Connexion réussie! Bienvenue ${_emailController.text}'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/home');
          }
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

  Future<void> _handleVisitorMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user', 'Visiteur');
      await prefs.setString('current_user_type', 'visiteur');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode visiteur activé - Vous pouvez explorer sans réserver'),
            backgroundColor: Colors.orange,
          ),
        );
        context.go('/home');
      }
    } catch (e) {
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
                      
                      // Login form fields
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
                      const SizedBox(height: 24),
                      
                      // Login button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Se connecter',
                            style: TextStyle(
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
    super.dispose();
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _stadeNomController = TextEditingController();
  final _stadeAdresseController = TextEditingController();
  final _stadePrixController = TextEditingController();
  
  String _userType = 'client';
  String _stadeCapacite = '11v11';
  String _stadeType = 'Terrain en herbe naturelle';

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les mots de passe ne correspondent pas'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Check if email already exists
        final existingUser = prefs.getString('user_${_emailController.text}');
        if (existingUser != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cet email est déjà utilisé'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // Save user data
        await prefs.setString('user_${_emailController.text}', _passwordController.text);
        await prefs.setString('username_${_emailController.text}', _nomController.text);
        await prefs.setString('usertype_${_emailController.text}', _userType);

        // Save stadium data if user is manager
        if (_userType == 'gestionnaire') {
          final stadeData = {
            'nom': _stadeNomController.text,
            'adresse': _stadeAdresseController.text,
            'prix': int.parse(_stadePrixController.text),
            'capacite': _stadeCapacite,
            'type': _stadeType,
            'gestionnaire': _emailController.text,
          };
          await prefs.setString('stade_${_emailController.text}', 
              '${stadeData['nom']}|${stadeData['adresse']}|${stadeData['prix']}|${stadeData['capacite']}|${stadeData['type']}|${stadeData['gestionnaire']}');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Compte créé avec succès! Connectez-vous maintenant avec ${_emailController.text}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Connexion',
                textColor: Colors.white,
                onPressed: () => context.go('/login'),
              ),
            ),
          );
          context.go('/login');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E88E5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Inscription'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? 64 : 24,
              vertical: 24,
            ),
            child: Form(
              key: _formKey,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
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
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E88E5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // User type selection
                    const Text('Type de compte:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Client'),
                            value: 'client',
                            groupValue: _userType,
                            onChanged: (value) => setState(() => _userType = value!),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Gestionnaire'),
                            value: 'gestionnaire',
                            groupValue: _userType,
                            onChanged: (value) => setState(() => _userType = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Basic user fields
                    TextFormField(
                      controller: _nomController,
                      decoration: InputDecoration(
                        labelText: 'Nom complet *',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Email requis';
                        if (!value!.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe *',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Mot de passe requis';
                        if (value!.length < 6) return 'Au moins 6 caractères';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmer mot de passe *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value?.isEmpty == true ? 'Confirmation requise' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Stadium fields for managers only
                    if (_userType == 'gestionnaire') ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Informations du stade',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _stadeNomController,
                              decoration: InputDecoration(
                                labelText: 'Nom du stade *',
                                prefixIcon: const Icon(Icons.sports_soccer),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) => _userType == 'gestionnaire' && value?.isEmpty == true 
                                  ? 'Nom du stade requis' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _stadeAdresseController,
                              decoration: InputDecoration(
                                labelText: 'Adresse *',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) => _userType == 'gestionnaire' && value?.isEmpty == true 
                                  ? 'Adresse requise' : null,
                            ),
                            const SizedBox(height: 16),
                            
                            TextFormField(
                              controller: _stadePrixController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Prix par heure (FCFA) *',
                                prefixIcon: const Icon(Icons.attach_money),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              validator: (value) {
                                if (_userType == 'gestionnaire' && value?.isEmpty == true) {
                                  return 'Prix requis';
                                }
                                if (_userType == 'gestionnaire' && int.tryParse(value!) == null) {
                                  return 'Prix invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _stadeCapacite,
                                    decoration: InputDecoration(
                                      labelText: 'Capacité',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: ['5v5', '7v7', '11v11'].map((capacite) => DropdownMenuItem(
                                      value: capacite,
                                      child: Text(capacite),
                                    )).toList(),
                                    onChanged: (value) => setState(() => _stadeCapacite = value!),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _stadeType,
                                    decoration: InputDecoration(
                                      labelText: 'Type',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    items: [
                                      'Terrain en herbe naturelle',
                                      'Terrain synthétique', 
                                      'Terrain en terre battue'
                                    ].map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    )).toList(),
                                    onChanged: (value) => setState(() => _stadeType = value!),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Register button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Créer le compte',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Back to login
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Déjà un compte ? Se connecter'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _stadeNomController.dispose();
    _stadeAdresseController.dispose();
    _stadePrixController.dispose();
    super.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentUser = '';
  String _currentUserType = 'visiteur';
  String _currentUserName = '';
  String _selectedTab = 'stades';
  List<Map<String, dynamic>> _stades = [];
  List<ReservationRequest> _userReservations = [];
  List<ReservationRequest> _managerRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUser = prefs.getString('current_user') ?? 'Visiteur';
      _currentUserType = prefs.getString('current_user_type') ?? 'visiteur';
      _currentUserName = prefs.getString('username_$_currentUser') ?? _currentUser;
      
      await _loadStades();
      if (_currentUserType == 'client') {
        await _loadUserReservations();
      } else if (_currentUserType == 'gestionnaire') {
        await _loadManagerRequests();
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadStades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (_currentUserType == 'gestionnaire') {
        // Load only manager's stadium
        final stadeData = prefs.getString('stade_$_currentUser');
        if (stadeData != null) {
          // Parse the stadium data (pipe-separated format)
          final parts = stadeData.split('|');
          if (parts.length >= 6) {
            final Map<String, dynamic> managerStade = {
              'nom': parts[0],
              'adresse': parts[1], 
              'prix': int.tryParse(parts[2]) ?? 0,
              'capacite': parts[3],
              'type': parts[4],
              'gestionnaire': parts[5],
              'disponible': true,
              'quartier': parts[1], // Use address as quartier
              'description': 'Stade géré par ${_currentUserName}',
            };
            _stades = [managerStade];
          }
        }
      } else {
        // Load all stadiums for clients and visitors
        _stades = [
          {
            'nom': 'Stade Ahmadou Ahidjo',
            'quartier': 'Centre-ville',
            'prix': 25000,
            'type': 'Terrain en herbe naturelle',
            'capacite': '11v11',
            'disponible': true,
            'description': 'Stade principal de Yaoundé avec éclairage nocturne',
            'gestionnaire': 'admin@bookfoot.cm',
          },
          {
            'nom': 'Terrain Municipal Tsinga',
            'quartier': 'Tsinga',
            'prix': 15000,
            'type': 'Terrain synthétique',
            'capacite': '7v7',
            'disponible': true,
            'description': 'Terrain moderne avec surface synthétique',
            'gestionnaire': 'tsinga@bookfoot.cm',
          },
          {
            'nom': 'Complexe Sportif Bastos',
            'quartier': 'Bastos',
            'prix': 30000,
            'type': 'Terrain en herbe naturelle',
            'capacite': '11v11',
            'disponible': true,
            'description': 'Complexe haut de gamme avec plusieurs terrains',
            'gestionnaire': 'bastos@bookfoot.cm',
          },
          {
            'nom': 'Terrain de Quartier Melen',
            'quartier': 'Melen',
            'prix': 8000,
            'type': 'Terrain en terre battue',
            'capacite': '5v5',
            'disponible': true,
            'description': 'Terrain communautaire accessible',
            'gestionnaire': 'melen@bookfoot.cm',
          },
        ];
        
        // Also include registered manager stadiums
        final keys = prefs.getKeys();
        for (final key in keys) {
          if (key.startsWith('stade_') && !key.contains(_currentUser)) {
            final stadeData = prefs.getString(key);
            if (stadeData != null) {
              final parts = stadeData.split('|');
              if (parts.length >= 6) {
                final Map<String, dynamic> stade = {
                  'nom': parts[0],
                  'adresse': parts[1], 
                  'prix': int.tryParse(parts[2]) ?? 0,
                  'capacite': parts[3],
                  'type': parts[4],
                  'gestionnaire': parts[5],
                  'disponible': true,
                  'quartier': parts[1], // Use address as quartier
                  'description': 'Stade privé disponible à la réservation',
                };
                _stades.add(stade);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading stadiums: $e');
    }
  }

  Future<void> _loadUserReservations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestIds = prefs.getStringList('reservation_requests') ?? [];
      _userReservations.clear();
      
      for (final id in requestIds) {
        try {
          final requestData = prefs.getString('request_$id');
          if (requestData != null) {
            final parts = requestData.split('|');
            if (parts.length >= 9 && parts[2] == _currentUser) {
              final request = ReservationRequest(
                id: id,
                stadeId: parts[0],
                stadeNom: parts[0],
                clientNom: parts[1],
                clientEmail: parts[2],
                dateReservation: DateFormat('dd/MM/yyyy').parse(parts[3]),
                heureDebut: parts[4],
                heureFin: parts[5],
                raison: parts[6],
                statut: parts[7],
                dateCreation: DateFormat('dd/MM/yyyy HH:mm').parse(parts[8]),
              );
              _userReservations.add(request);
            }
          }
        } catch (e) {
          debugPrint('Error parsing reservation $id: $e');
          // Skip this reservation and continue with others
          continue;
        }
      }
      
      // Sort by date creation (most recent first)
      _userReservations.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    } catch (e) {
      debugPrint('Error loading user reservations: $e');
    }
  }

  Future<void> _loadManagerRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestIds = prefs.getStringList('reservation_requests') ?? [];
      _managerRequests.clear();
      
      // Get manager's stadium name
      final stadeData = prefs.getString('stade_$_currentUser');
      String? managerStadeName;
      if (stadeData != null) {
        final parts = stadeData.split('|');
        if (parts.isNotEmpty) {
          managerStadeName = parts[0]; // First part is the stadium name
        }
      }
      
      if (managerStadeName != null) {
        for (final id in requestIds) {
          try {
            final requestData = prefs.getString('request_$id');
            if (requestData != null) {
              final parts = requestData.split('|');
              if (parts.length >= 9 && parts[0] == managerStadeName) {
                final request = ReservationRequest(
                  id: id,
                  stadeId: parts[0],
                  stadeNom: parts[0],
                  clientNom: parts[1],
                  clientEmail: parts[2],
                  dateReservation: DateFormat('dd/MM/yyyy').parse(parts[3]),
                  heureDebut: parts[4],
                  heureFin: parts[5],
                  raison: parts[6],
                  statut: parts[7],
                  dateCreation: DateFormat('dd/MM/yyyy HH:mm').parse(parts[8]),
                );
                _managerRequests.add(request);
              }
            }
          } catch (e) {
            debugPrint('Error parsing manager request $id: $e');
            // Skip this request and continue with others
            continue;
          }
        }
      }
      
      // Sort by date creation (most recent first)
      _managerRequests.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));
    } catch (e) {
      debugPrint('Error loading manager requests: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('BookFoot237 - ${_getUserTypeDisplay()}'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/login'),
            tooltip: 'Se déconnecter',
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
      body: _buildBody(),
    );
  }

  String _getUserTypeDisplay() {
    switch (_currentUserType) {
      case 'client':
        return 'Client';
      case 'gestionnaire':
        return 'Gestionnaire';
      case 'visiteur':
        return 'Visiteur';
      default:
        return 'Utilisateur';
    }
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1E88E5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sports_soccer,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bonjour,',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _currentUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getUserTypeDisplay(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (_currentUserType == 'gestionnaire') ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Mon Stade'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.pending_actions),
              title: const Text('Demandes de Réservation'),
              selected: _selectedTab == 'demandes',
              onTap: () {
                setState(() {
                  _selectedTab = 'demandes';
                });
                Navigator.pop(context);
              },
            ),
          ] else if (_currentUserType == 'client') ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Terrains Disponibles'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Mes Réservations'),
              selected: _selectedTab == 'historique',
              onTap: () {
                setState(() {
                  _selectedTab = 'historique';
                });
                Navigator.pop(context);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.stadium),
              title: const Text('Explorer les Terrains'),
              selected: _selectedTab == 'stades',
              onTap: () {
                setState(() {
                  _selectedTab = 'stades';
                });
                Navigator.pop(context);
              },
            ),
          ],
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Se Déconnecter', style: TextStyle(color: Colors.red)),
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 'stades':
        return _buildStadesView();
      case 'historique':
        return _buildHistoriqueView();
      case 'demandes':
        return _buildDemandesView();
      default:
        return _buildStadesView();
    }
  }

  Widget _buildStadesView() {
    return Column(
      children: [
        if (_currentUserType != 'gestionnaire') ...[
          // Search bar for clients and visitors
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un stade...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: true,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('11v11'),
                  selected: false,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('7v7'),
                  selected: false,
                  onSelected: (selected) {},
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('5v5'),
                  selected: false,
                  onSelected: (selected) {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Header for manager
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Interface Gestionnaire',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Voici votre stade et les informations de gestion.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
        
        // Stades list
        Expanded(
          child: _stades.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.stadium,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _currentUserType == 'gestionnaire'
                            ? 'Aucun stade configuré'
                            : 'Aucun terrain disponible',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth > 600;
                    
                    if (isTablet) {
                      return GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: _stades.length,
                        itemBuilder: (context, index) {
                          return _buildStadeCard(context, _stades[index]);
                        },
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _stades.length,
                      itemBuilder: (context, index) {
                        return _buildStadeCard(context, _stades[index]);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoriqueView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique de vos Réservations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Consultez toutes vos demandes de réservation.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Expanded(
          child: _userReservations.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune réservation trouvée',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Vos demandes de réservation apparaîtront ici',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _userReservations.length,
                  itemBuilder: (context, index) {
                    return _buildReservationCard(_userReservations[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDemandesView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Demandes de Réservation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Gérez les demandes de réservation pour votre stade.',
                style: TextStyle(color: Colors.grey[700]),
              ),
            ],
          ),
        ),
        Expanded(
          child: _managerRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.pending_actions,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune demande de réservation',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Les demandes pour votre stade apparaîtront ici',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _managerRequests.length,
                  itemBuilder: (context, index) {
                    return _buildManagerRequestCard(_managerRequests[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildReservationCard(ReservationRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (request.statut) {
      case 'en_attente':
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case 'accepte':
        statusColor = Colors.green;
        statusText = 'Acceptée';
        statusIcon = Icons.check_circle;
        break;
      case 'refuse':
        statusColor = Colors.red;
        statusText = 'Refusée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stadium,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.stadeNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(request.dateReservation),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${request.heureDebut} - ${request.heureFin}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (request.raison.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Raison: ${request.raison}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Demandé le ${DateFormat('dd/MM/yyyy à HH:mm').format(request.dateCreation)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerRequestCard(ReservationRequest request) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (request.statut) {
      case 'en_attente':
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case 'accepte':
        statusColor = Colors.green;
        statusText = 'Acceptée';
        statusIcon = Icons.check_circle;
        break;
      case 'refuse':
        statusColor = Colors.red;
        statusText = 'Refusée';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
        statusIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.clientNom,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        statusText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Email: ${request.clientEmail}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd/MM/yyyy').format(request.dateReservation),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  '${request.heureDebut} - ${request.heureFin}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            if (request.raison.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Raison: ${request.raison}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (request.statut == 'en_attente') ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleRequestAction(request.id, 'accepte'),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accepter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleRequestAction(request.id, 'refuse'),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Refuser'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Demandé le ${DateFormat('dd/MM/yyyy à HH:mm').format(request.dateCreation)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequestAction(String requestId, String newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final requestData = prefs.getString('request_$requestId');
      
      if (requestData != null) {
        final parts = requestData.split('|');
        if (parts.length >= 9) {
          // Update the status part
          parts[7] = newStatus;
          final updatedData = parts.join('|');
          await prefs.setString('request_$requestId', updatedData);
          
          // Refresh the manager requests
          await _loadManagerRequests();
          setState(() {});
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                newStatus == 'accepte' 
                    ? 'Demande acceptée avec succès' 
                    : 'Demande refusée',
              ),
              backgroundColor: newStatus == 'accepte' ? Colors.green : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildStadeCard(BuildContext context, Map<String, dynamic> stade) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          _showStadeDetails(context, stade);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Icon(
                Icons.sports_soccer,
                size: 60,
                color: Colors.grey,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          stade['nom'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stade['disponible'] ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          stade['disponible'] ? 'Disponible' : 'Occupé',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          stade['quartier'],
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        stade['capacite'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stade['description'],
                    style: TextStyle(color: Colors.grey[800], fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${stade['prix']} FCFA/h',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _showReservationDialog(context, stade);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: const Text(
                          'Réserver',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStadeDetails(BuildContext context, Map<String, dynamic> stade) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stade['nom']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📍 Quartier: ${stade['quartier']}'),
            Text('⚽ Capacité: ${stade['capacite']}'),
            Text('🏟️ Type: ${stade['type']}'),
            Text('💰 Prix: ${stade['prix']} FCFA/heure'),
            const SizedBox(height: 16),
            const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(stade['description']),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showReservationDialog(context, stade);
            },
            child: const Text('Réserver'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReservationDialog(BuildContext context, Map<String, dynamic> stade) async {
    try {
      showDialog(
        context: context,
        builder: (context) => ReservationDialog(stade: stade),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class ReservationDialog extends StatefulWidget {
  final Map<String, dynamic> stade;

  const ReservationDialog({super.key, required this.stade});

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _raisonController = TextEditingController();
  
  DateTime _dateReservation = DateTime.now().add(const Duration(days: 1));
  String _heureDebut = '08:00';
  String _heureFin = '10:00';
  
  final List<String> _heures = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
    '20:00', '21:00', '22:00'
  ];

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = prefs.getString('current_user') ?? '';
      final userName = prefs.getString('username_$currentUser') ?? currentUser;
      
      _nomController.text = userName;
      _emailController.text = currentUser; // current_user stores the email
      setState(() {});
    } catch (e) {
      debugPrint('Error loading user info: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReservation,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _dateReservation = picked;
      });
    }
  }

  int _calculateDuration() {
    final debut = _heures.indexOf(_heureDebut);
    final fin = _heures.indexOf(_heureFin);
    return fin - debut;
  }

  int _calculateTotal() {
    final duration = _calculateDuration();
    return duration > 0 ? (widget.stade['prix'] as int) * duration : 0;
  }

  Future<void> _submitReservation() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Check user type first - block visitors
        final prefs = await SharedPreferences.getInstance();
        final currentUser = prefs.getString('current_user');
        final userType = prefs.getString('current_user_type') ?? 'visiteur';
        
        if (currentUser == null || userType == 'visiteur') {
          // Show visitor blocking dialog
          _showVisitorBlockDialog();
          return;
        }
        
        // Validate required fields
        if (_nomController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le nom est requis'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Un email valide est requis'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        if (_raisonController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('La raison de la réservation est requise'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        final request = ReservationRequest(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          stadeId: widget.stade['nom'],
          stadeNom: widget.stade['nom'],
          clientNom: _nomController.text.trim(),
          clientEmail: _emailController.text.trim(),
          dateReservation: _dateReservation,
          heureDebut: _heureDebut,
          heureFin: _heureFin,
          raison: _raisonController.text.trim(),
          statut: 'en_attente',
          dateCreation: DateTime.now(),
        );

        final requests = prefs.getStringList('reservation_requests') ?? [];
        requests.add(request.id);
        await prefs.setStringList('reservation_requests', requests);
        await prefs.setString('request_${request.id}', 
            '${request.stadeNom}|${request.clientNom}|${request.clientEmail}|'
            '${DateFormat('dd/MM/yyyy').format(request.dateReservation)}|'
            '${request.heureDebut}|${request.heureFin}|${request.raison}|'
            '${request.statut}|${DateFormat('dd/MM/yyyy HH:mm').format(request.dateCreation)}');

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Demande de réservation envoyée avec succès pour ${widget.stade['nom']}!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: () {
                  _showRequestDetails(request);
                },
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'envoi de la demande: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      // Show validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez corriger les erreurs dans le formulaire'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRequestDetails(ReservationRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demande envoyée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🏟️ ${request.stadeNom}'),
            Text('📅 ${DateFormat('dd/MM/yyyy').format(request.dateReservation)}'),
            Text('⏰ ${request.heureDebut} - ${request.heureFin}'),
            Text('💰 ${_calculateTotal()} FCFA'),
            const SizedBox(height: 8),
            Text('📝 ${request.raison}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⏳ En attente de validation du gestionnaire',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVisitorBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Réservation impossible',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vous ne pouvez pas effectuer de réservation en tant que visiteur.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                '💡 Pour effectuer des réservations, vous devez créer un compte client ou gestionnaire.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close reservation form
              // Navigate to registration
              context.go('/register');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Créer un compte pour réserver'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = _calculateDuration();
    final total = _calculateTotal();
    
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.sports_soccer, color: Colors.blue.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Réserver ${widget.stade['nom']}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet *',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Nom requis' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value?.isEmpty == true) return 'Email requis';
                          if (!value!.contains('@')) return 'Email invalide';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today),
                              const SizedBox(width: 8),
                              Text('Date: ${DateFormat('dd/MM/yyyy').format(_dateReservation)}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _heureDebut,
                              decoration: const InputDecoration(
                                labelText: 'Heure début',
                                border: OutlineInputBorder(),
                              ),
                              items: _heures.map((heure) => DropdownMenuItem(
                                value: heure,
                                child: Text(heure),
                              )).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _heureDebut = value!;
                                  if (_heures.indexOf(_heureDebut) >= _heures.indexOf(_heureFin)) {
                                    final index = _heures.indexOf(_heureDebut) + 1;
                                    if (index < _heures.length) {
                                      _heureFin = _heures[index];
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _heureFin,
                              decoration: const InputDecoration(
                                labelText: 'Heure fin',
                                border: OutlineInputBorder(),
                              ),
                              items: _heures.where((heure) => 
                                _heures.indexOf(heure) > _heures.indexOf(_heureDebut)
                              ).map((heure) => DropdownMenuItem(
                                value: heure,
                                child: Text(heure),
                              )).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _heureFin = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _raisonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Raison de la réservation *',
                          hintText: 'Ex: Entraînement équipe, Match amical...',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value?.isEmpty == true ? 'Raison requise' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Text('Durée: $duration heure(s)', 
                              style: const TextStyle(fontSize: 16)),
                            Text('Total: $total FCFA', 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: duration > 0 ? _submitReservation : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Envoyer la demande'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _emailController.dispose();
    _raisonController.dispose();
    super.dispose();
  }
}