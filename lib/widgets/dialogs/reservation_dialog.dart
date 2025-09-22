import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/stadium.dart';
import '../../models/reservation_request.dart';
import '../../services/notification_service.dart';
import '../../services/firebase_reservation_service.dart';
import '../../utils/form_validators.dart';

class ReservationDialog extends StatefulWidget {
  final Stadium stadium;
  final String clientName;
  final String clientEmail;

  const ReservationDialog({
    super.key,
    required this.stadium,
    required this.clientName,
    required this.clientEmail,
  });

  @override
  State<ReservationDialog> createState() => _ReservationDialogState();
}

class _ReservationDialogState extends State<ReservationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _raisonController = TextEditingController();
  final _heureDebutController = TextEditingController();
  final _heureFinController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      print('🔧 DEBUG - Création réservation dialog:');
      print('   - Stadium ID: ${widget.stadium.id}');
      print('   - Stadium Name: ${widget.stadium.nom}');
      print('   - Stadium Manager: ${widget.stadium.gestionnaire}');
      print('   - Client Name: ${widget.clientName}');
      print('   - Client Email: ${widget.clientEmail}');

      final reservation = ReservationRequest(
        id: '', // Will be set by Firebase
        stadeId: widget.stadium.id,
        stadeNom: widget.stadium.nom,
        stadiumManager: widget.stadium.gestionnaire,
        clientNom: widget.clientName,
        clientEmail: widget.clientEmail,
        dateReservation: _selectedDate,
        heureDebut: _heureDebutController.text.trim(),
        heureFin: _heureFinController.text.trim(),
        raison: _raisonController.text.trim(),
        statut: 'en_attente',
        dateCreation: DateTime.now(),
      );

      print('🔧 DEBUG - Réservation créée (avant envoi Firebase):');
      print('   - stadiumManager: ${reservation.stadiumManager}');

      // Save reservation to Firebase
      final reservationId = await FirebaseReservationService.createReservation(reservation);

      if (reservationId != null) {
        print('✅ Réservation sauvegardée avec ID: $reservationId');

        // Send notification to stadium manager
        await NotificationService.instance.sendReservationNotification(
          managerEmail: widget.stadium.gestionnaire,
          reservation: reservation.copyWith(id: reservationId),
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Demande de réservation envoyée avec succès!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Impossible de créer la réservation');
      }
    } catch (e) {
      print('❌ Erreur création réservation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sports_soccer, color: Color(0xFF1E88E5)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Réserver ${widget.stadium.nom}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Stadium info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.stadium.nom,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.stadium.adresse,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.stadium.prix.toInt()} FCFA/heure',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Date selection
                      ListTile(
                        title: const Text('Date de réservation'),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                        leading: const Icon(Icons.calendar_today),
                        onTap: _selectDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Time inputs
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heureDebutController,
                              decoration: const InputDecoration(
                                labelText: 'Heure début',
                                hintText: '14:00',
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              validator: FormValidators.validateTime,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _heureFinController,
                              decoration: const InputDecoration(
                                labelText: 'Heure fin',
                                hintText: '16:00',
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              validator: FormValidators.validateTime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Reason
                      TextFormField(
                        controller: _raisonController,
                        decoration: const InputDecoration(
                          labelText: 'Raison de la réservation',
                          hintText: 'Match amical, entraînement, etc.',
                          prefixIcon: Icon(Icons.note),
                        ),
                        maxLines: 3,
                        validator: (value) => FormValidators.validateRequired(value, 'Raison'),
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitReservation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E88E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Envoyer la demande',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _raisonController.dispose();
    _heureDebutController.dispose();
    _heureFinController.dispose();
    super.dispose();
  }
}