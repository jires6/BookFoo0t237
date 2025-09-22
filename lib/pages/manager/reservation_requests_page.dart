import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/reservation_request.dart';
import '../../services/firebase_reservation_service.dart';
import '../../services/firebase_stadium_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/debug_helper.dart';

class ReservationRequestsPage extends StatefulWidget {
  const ReservationRequestsPage({super.key});

  @override
  State<ReservationRequestsPage> createState() => _ReservationRequestsPageState();
}

class _ReservationRequestsPageState extends State<ReservationRequestsPage> {
  List<ReservationRequest> _reservations = [];
  bool _isLoading = true;
  String _currentUser = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUser = prefs.getString('current_user') ?? '';
    });
    AppLogger.info('🔧 DEBUG - Gestionnaire connecté: $_currentUser');
    await _loadReservations();
  }

  Future<void> _loadReservations() async {
    if (_currentUser.isEmpty) {
      setState(() {
        _reservations = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Utiliser directement l'email du gestionnaire pour récupérer ses réservations
      final reservations = await FirebaseReservationService.getManagerReservationsByEmail(_currentUser);

      setState(() {
        _reservations = reservations;
        _isLoading = false;
      });

      AppLogger.info('Réservations chargées pour le gestionnaire $_currentUser: ${reservations.length} réservations');
    } catch (e) {
      setState(() => _isLoading = false);
      AppLogger.error('Erreur lors du chargement des réservations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateReservationStatus(ReservationRequest reservation, String newStatus) async {
    try {
      final success = await FirebaseReservationService.updateReservationStatus(
        reservation.id,
        newStatus,
      );

      if (success) {
        await _loadReservations(); // Recharger la liste

        String message = newStatus == 'acceptee'
            ? 'Réservation acceptée'
            : 'Réservation refusée';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: newStatus == 'acceptee' ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de la mise à jour');
      }
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du statut: $e');
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

  Future<void> _showReservationActions(ReservationRequest reservation) async {
    return showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Actions pour la réservation',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              if (reservation.statut == 'en_attente') ...[
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text('Accepter'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateReservationStatus(reservation, 'acceptee');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text('Refuser'),
                  onTap: () {
                    Navigator.pop(context);
                    _updateReservationStatus(reservation, 'refusee');
                  },
                ),
              ],

              ListTile(
                leading: const Icon(Icons.info, color: Colors.blue),
                title: const Text('Voir détails'),
                onTap: () {
                  Navigator.pop(context);
                  _showReservationDetails(reservation);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReservationDetails(ReservationRequest reservation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Détails de la réservation'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Stade:', reservation.stadeNom),
                _buildDetailRow('Client:', reservation.clientNom),
                _buildDetailRow('Email:', reservation.clientEmail),
                _buildDetailRow('Date:', DateFormat('dd/MM/yyyy').format(reservation.dateReservation)),
                _buildDetailRow('Heure:', '${reservation.heureDebut} - ${reservation.heureFin}'),
                _buildDetailRow('Raison:', reservation.raison),
                _buildDetailRow('Statut:', _getStatusText(reservation.statut)),
                _buildDetailRow('Demande créée:', DateFormat('dd/MM/yyyy à HH:mm').format(reservation.dateCreation)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'en_attente':
        return 'En attente';
      case 'acceptee':
        return 'Acceptée';
      case 'refusee':
        return 'Refusée';
      case 'annulee':
        return 'Annulée';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'en_attente':
        return Colors.orange;
      case 'acceptee':
        return Colors.green;
      case 'refusee':
        return Colors.red;
      case 'annulee':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes de Réservation'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReservations,
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'debug_create':
                  await DebugHelper.createTestReservation();
                  await _loadReservations();
                  break;
                case 'debug_list':
                  await DebugHelper.listAllReservations();
                  break;
                case 'debug_check':
                  await DebugHelper.checkManagerCanSeeReservation(_currentUser);
                  break;
                case 'debug_clean':
                  await DebugHelper.cleanupTestReservations();
                  await _loadReservations();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'debug_create',
                child: Text('🔧 Créer réservation test'),
              ),
              const PopupMenuItem(
                value: 'debug_list',
                child: Text('📊 Lister toutes réservations'),
              ),
              const PopupMenuItem(
                value: 'debug_check',
                child: Text('🔍 Vérifier mes réservations'),
              ),
              const PopupMenuItem(
                value: 'debug_clean',
                child: Text('🧹 Nettoyer tests'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reservations.isEmpty
              ? _buildEmptyState()
              : _buildReservationsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune demande de réservation',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les demandes pour vos stades apparaîtront ici',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationsList() {
    return RefreshIndicator(
      onRefresh: _loadReservations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reservations.length,
        itemBuilder: (context, index) {
          final reservation = _reservations[index];
          return _buildReservationCard(reservation);
        },
      ),
    );
  }

  Widget _buildReservationCard(ReservationRequest reservation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: InkWell(
        onTap: () => _showReservationActions(reservation),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec stade et statut
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reservation.stadeNom,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(reservation.statut),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(reservation.statut),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Informations client
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${reservation.clientNom} (${reservation.clientEmail})',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date et heure
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd/MM/yyyy').format(reservation.dateReservation),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${reservation.heureDebut} - ${reservation.heureFin}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Raison
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reservation.raison,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Actions rapides (seulement pour les demandes en attente)
              if (reservation.statut == 'en_attente')
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _updateReservationStatus(reservation, 'refusee'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Refuser'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _updateReservationStatus(reservation, 'acceptee'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accepter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

              // Date de création
              const SizedBox(height: 8),
              Text(
                'Demande reçue le ${DateFormat('dd/MM/yyyy à HH:mm').format(reservation.dateCreation)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}