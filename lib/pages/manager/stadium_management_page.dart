import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/stadium.dart';
import '../../services/firebase_stadium_service.dart';
import '../../utils/app_logger.dart';
import '../../widgets/dialogs/stadium_form_dialog.dart';

class StadiumManagementPage extends StatefulWidget {
  const StadiumManagementPage({super.key});

  @override
  State<StadiumManagementPage> createState() => _StadiumManagementPageState();
}

class _StadiumManagementPageState extends State<StadiumManagementPage> {
  List<Stadium> _stadiums = [];
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
    await _loadStadiums();
  }

  Future<void> _loadStadiums() async {
    if (_currentUser.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final stadiums = await FirebaseStadiumService.getStadiumsByManager(_currentUser);
      setState(() {
        _stadiums = stadiums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      AppLogger.error('Erreur lors du chargement des stades: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showStadiumForm({Stadium? stadium}) async {
    final result = await showDialog<Stadium>(
      context: context,
      builder: (context) => StadiumFormDialog(
        stadium: stadium,
        currentUser: _currentUser,
      ),
    );

    if (result != null) {
      await _loadStadiums();
    }
  }

  Future<void> _deleteStadium(Stadium stadium) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le stade "${stadium.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await FirebaseStadiumService.deleteStadium(stadium.id);
        if (success) {
          await _loadStadiums();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stade supprimé avec succès'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Erreur lors de la suppression');
        }
      } catch (e) {
        AppLogger.error('Erreur lors de la suppression: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Stades'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStadiums,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _stadiums.isEmpty
              ? _buildEmptyState()
              : _buildStadiumsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStadiumForm(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.stadium,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun stade créé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour créer votre premier stade',
            style: TextStyle(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStadiumsList() {
    return RefreshIndicator(
      onRefresh: _loadStadiums,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _stadiums.length,
        itemBuilder: (context, index) {
          final stadium = _stadiums[index];
          return _buildStadiumCard(stadium);
        },
      ),
    );
  }

  Widget _buildStadiumCard(Stadium stadium) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stadium.nom,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        stadium.adresse,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stadium.disponible ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stadium.disponible ? 'Disponible' : 'Indisponible',
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
            Row(
              children: [
                _buildInfoChip(Icons.location_on, stadium.quartier),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.sports_soccer, stadium.type),
                const SizedBox(width: 8),
                _buildInfoChip(Icons.attach_money, '${stadium.prix} FCFA'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              stadium.description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _showStadiumForm(stadium: stadium),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteStadium(stadium),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}