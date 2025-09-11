import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer le cycle de vie de l'application
/// et empêcher la destruction automatique
class AppLifecycleService extends WidgetsBindingObserver {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  bool _isInitialized = false;
  AppLifecycleState? _lastLifecycleState;
  Timer? _keepAliveTimer;
  
  // Configuration du timer: maintenir l'app en vie pendant 5-10 minutes
  static const Duration _keepAliveDuration = Duration(minutes: 8); // 8 minutes par défaut
  static const Duration _keepAliveInterval = Duration(seconds: 30); // Signal toutes les 30 secondes

  /// Initialise le service de cycle de vie
  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
      _saveAppState('initialized');
      _startKeepAliveTimer();
      print('🔄 AppLifecycleService initialisé avec timer keepAlive');
    }
  }

  /// Nettoie le service
  void dispose() {
    if (_isInitialized) {
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      print('🔄 AppLifecycleService fermé');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    print('🔄 État app changé: ${state.name}');
    _lastLifecycleState = state;

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        _startKeepAliveTimer(); // Redémarre le timer en arrière-plan
        break;
      case AppLifecycleState.detached:
        _onAppDetached();
        break;
      case AppLifecycleState.inactive:
        _onAppInactive();
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  /// Quand l'app revient au premier plan
  void _onAppResumed() {
    _saveAppState('resumed');
    print('📱 App au premier plan');
    
    // Restaurer l'état si nécessaire
    _restoreAppState();
  }

  /// Quand l'app passe en arrière-plan
  void _onAppPaused() {
    _saveAppState('paused');
    print('📱 App en arrière-plan');
    
    // Sauvegarder l'état actuel
    _persistAppState();
  }

  /// Quand l'app est détachée
  void _onAppDetached() {
    _saveAppState('detached');
    print('📱 App détachée');
  }

  /// Quand l'app est inactive
  void _onAppInactive() {
    _saveAppState('inactive');
    print('📱 App inactive');
  }

  /// Quand l'app est cachée
  void _onAppHidden() {
    _saveAppState('hidden');
    print('📱 App cachée');
  }

  /// Sauvegarde l'état de l'application
  Future<void> _saveAppState(String state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_last_state', state);
      await prefs.setInt('app_last_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ Erreur sauvegarde état: $e');
    }
  }

  /// Persiste l'état de l'application
  Future<void> _persistAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('app_was_running', true);
      await prefs.setString('app_session_id', DateTime.now().toIso8601String());
      print('💾 État app persisté');
    } catch (e) {
      print('❌ Erreur persistance: $e');
    }
  }

  /// Restaure l'état de l'application
  Future<void> _restoreAppState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasRunning = prefs.getBool('app_was_running') ?? false;
      final sessionId = prefs.getString('app_session_id');
      
      if (wasRunning && sessionId != null) {
        print('🔄 Restauration session: $sessionId');
        // Ici vous pouvez restaurer des données spécifiques
      }
    } catch (e) {
      print('❌ Erreur restauration: $e');
    }
  }

  /// Empêche la fermeture système de l'app
  Future<bool> preventSystemClose() async {
    try {
      // Utilise la méthode platform pour empêcher la fermeture
      await SystemChannels.platform.invokeMethod('SystemNavigator.pop', false);
      return false; // Empêche la fermeture
    } catch (e) {
      print('❌ Impossible d\'empêcher fermeture: $e');
      return true; // Permet la fermeture
    }
  }

  /// Getter pour l'état actuel
  AppLifecycleState? get currentState => _lastLifecycleState;

  /// Vérifie si l'app est active
  bool get isAppActive => 
    _lastLifecycleState == AppLifecycleState.resumed ||
    _lastLifecycleState == null; // null = première initialisation

  /// Méthode pour maintenir l'app en vie
  void keepAppAlive() {
    if (_isInitialized) {
      // Actualise le timestamp pour signaler que l'app est active
      _saveAppState('keepalive_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  /// Démarre le timer pour maintenir l'app en vie automatiquement
  void _startKeepAliveTimer() {
    // Annule le timer existant s'il y en a un
    _keepAliveTimer?.cancel();
    
    print('⏰ Démarrage timer keepAlive pour ${_keepAliveDuration.inMinutes} minutes');
    
    // Crée un timer périodique qui envoie des signaux réguliers
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (timer) {
      if (_isInitialized) {
        keepAppAlive();
        print('💓 Signal keepAlive envoyé (${timer.tick * _keepAliveInterval.inSeconds}s)');
      } else {
        timer.cancel();
      }
    });
    
    // Arrête automatiquement après la durée maximale
    Timer(_keepAliveDuration, () {
      _keepAliveTimer?.cancel();
      _keepAliveTimer = null;
      print('⏰ Timer keepAlive arrêté après ${_keepAliveDuration.inMinutes} minutes');
    });
  }

  /// Force le redémarrage du timer keepAlive
  void restartKeepAliveTimer() {
    print('🔄 Redémarrage forcé du timer keepAlive');
    _startKeepAliveTimer();
  }
}