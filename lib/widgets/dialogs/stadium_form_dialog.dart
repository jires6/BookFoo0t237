import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/stadium.dart';
import '../../services/firebase_stadium_service.dart';
import '../../utils/app_logger.dart';

class StadiumFormDialog extends StatefulWidget {
  final Stadium? stadium;
  final String currentUser;

  const StadiumFormDialog({
    super.key,
    this.stadium,
    required this.currentUser,
  });

  @override
  State<StadiumFormDialog> createState() => _StadiumFormDialogState();
}

class _StadiumFormDialogState extends State<StadiumFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _quartierController = TextEditingController();
  final _prixController = TextEditingController();
  final _capaciteController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'Football 11 vs 11';
  bool _isLoading = false;
  final List<File> _selectedImages = [];
  final ImagePicker _imagePicker = ImagePicker();

  final List<String> _types = [
    'Football 11 vs 11',
    'Football 7 vs 7',
    'Football 5 vs 5',
    'Foot en salle',
  ];

  final List<String> _quartiers = [
    'Yaoundé 1er',
    'Yaoundé 2ème',
    'Yaoundé 3ème',
    'Yaoundé 4ème',
    'Yaoundé 5ème',
    'Yaoundé 6ème',
    'Yaoundé 7ème',
    'Nlongkak',
    'Mvan',
    'Ekounou',
    'Emombo',
    'Nkomo',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.stadium != null) {
      _nomController.text = widget.stadium!.nom;
      _adresseController.text = widget.stadium!.adresse;
      // S'assurer que le quartier existe dans la liste
      if (_quartiers.contains(widget.stadium!.quartier)) {
        _quartierController.text = widget.stadium!.quartier;
      } else {
        _quartierController.text = _quartiers.first;
      }
      _prixController.text = widget.stadium!.prix.toString();
      _capaciteController.text = widget.stadium!.capacite;
      _descriptionController.text = widget.stadium!.description;
      // S'assurer que le type existe dans la liste
      if (_types.contains(widget.stadium!.type)) {
        _selectedType = widget.stadium!.type;
      } else {
        _selectedType = _types.first;
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _adresseController.dispose();
    _quartierController.dispose();
    _prixController.dispose();
    _capaciteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      AppLogger.error('Erreur lors de la sélection d\'image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection d\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Map<String, dynamic> _getDefaultSchedule() {
    return {
      'lundi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'mardi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'mercredi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'jeudi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'vendredi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'samedi': {'ouvert': true, 'debut': '06:00', 'fin': '22:00'},
      'dimanche': {'ouvert': true, 'debut': '08:00', 'fin': '20:00'},
    };
  }

  Future<void> _saveStadium() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? stadiumId;
      List<String> imageUrls = widget.stadium?.images ?? [];

      // Créer d'abord le stade pour obtenir l'ID
      if (widget.stadium == null) {
        final tempStadium = Stadium(
          id: '',
          nom: _nomController.text.trim(),
          adresse: _adresseController.text.trim(),
          quartier: _quartierController.text.trim(),
          prix: int.parse(_prixController.text.trim()),
          type: _selectedType,
          capacite: _capaciteController.text.trim(),
          description: _descriptionController.text.trim(),
          gestionnaire: widget.currentUser,
          disponible: true,
          images: [],
          horaires: _getDefaultSchedule(),
          dateCreation: null,
          amenities: {},
        );
        stadiumId = await FirebaseStadiumService.createStadium(tempStadium);
        if (stadiumId == null) {
          throw Exception('Erreur lors de la création du stade');
        }
      } else {
        stadiumId = widget.stadium!.id;
      }

      // Uploader les nouvelles images si il y en a
      if (_selectedImages.isNotEmpty) {
        final uploadedUrls = <String>[];
        for (final imageFile in _selectedImages) {
          try {
            final bytes = await imageFile.readAsBytes();
            final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
            final filePath = 'stadiums/$stadiumId/$fileName';

            await Supabase.instance.client.storage
                .from('bucketBookFoot237')
                .uploadBinary(filePath, bytes);

            final publicUrl = Supabase.instance.client.storage
                .from('bucketBookFoot237')
                .getPublicUrl(filePath);

            uploadedUrls.add(publicUrl);
          } catch (e) {
            AppLogger.error('Erreur upload image: $e');
          }
        }
        imageUrls.addAll(uploadedUrls);
      }

      // Créer/mettre à jour le stade avec les images
      final stadium = Stadium(
        id: stadiumId,
        nom: _nomController.text.trim(),
        adresse: _adresseController.text.trim(),
        quartier: _quartierController.text.trim(),
        prix: int.parse(_prixController.text.trim()),
        type: _selectedType,
        capacite: _capaciteController.text.trim(),
        description: _descriptionController.text.trim(),
        gestionnaire: widget.currentUser,
        disponible: widget.stadium?.disponible ?? true,
        images: imageUrls,
        horaires: widget.stadium?.horaires ?? _getDefaultSchedule(),
        dateCreation: widget.stadium?.dateCreation,
        amenities: widget.stadium?.amenities ?? {},
      );

      bool success;
      if (widget.stadium == null) {
        // Mettre à jour le stade créé avec les images
        success = await FirebaseStadiumService.updateStadium(stadiumId, stadium);
      } else {
        // Mettre à jour le stade existant
        success = await FirebaseStadiumService.updateStadium(stadiumId, stadium);
      }

      if (success) {
        if (mounted) {
          Navigator.of(context).pop(stadium);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.stadium == null
                  ? 'Stade créé avec succès'
                  : 'Stade mis à jour avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Erreur lors de l\'enregistrement');
      }
    } catch (e) {
      AppLogger.error('Erreur lors de l\'enregistrement du stade: $e');
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
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stadium, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.stadium == null ? 'Nouveau Stade' : 'Modifier le Stade',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Formulaire
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du stade *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.stadium),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _adresseController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'L\'adresse est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      DropdownButtonFormField<String>(
                        value: _quartiers.contains(_quartierController.text) && _quartierController.text.isNotEmpty
                            ? _quartierController.text
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Quartier *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_city),
                        ),
                        items: _quartiers.map((quartier) {
                          return DropdownMenuItem(
                            value: quartier,
                            child: Text(quartier),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _quartierController.text = value;
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le quartier est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: 'Type de sport *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sports_soccer),
                              ),
                              items: _types.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(type),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedType = value);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _prixController,
                              decoration: const InputDecoration(
                                labelText: 'Prix (FCFA) *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Le prix est obligatoire';
                                }
                                if (int.tryParse(value.trim()) == null) {
                                  return 'Prix invalide';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _capaciteController,
                        decoration: const InputDecoration(
                          labelText: 'Capacité *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.people),
                          hintText: 'Ex: 22 joueurs, 100 spectateurs',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La capacité est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          hintText: 'Décrivez votre stade, ses équipements...',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La description est obligatoire';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Section des images
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.photo_library, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text(
                                  'Images du stade',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.add_photo_alternate),
                                  label: const Text('Ajouter'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade100,
                                    foregroundColor: Colors.green.shade800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_selectedImages.isEmpty && (widget.stadium?.images.isEmpty ?? true))
                              Container(
                                height: 100,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.photo_library_outlined, size: 32, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text('Aucune image sélectionnée', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              )
                            else
                              SizedBox(
                                height: 120,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length + (widget.stadium?.images.length ?? 0),
                                  itemBuilder: (context, index) {
                                    if (index < _selectedImages.length) {
                                      // Nouvelles images sélectionnées
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                _selectedImages[index],
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: GestureDetector(
                                                onTap: () => _removeImage(index),
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      // Images existantes du stade
                                      final existingIndex = index - _selectedImages.length;
                                      final imageUrl = widget.stadium!.images[existingIndex];
                                      return Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(
                                            imageUrl,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 120,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(Icons.image_not_supported, color: Colors.grey),
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  },
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

            // Boutons d'action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveStadium,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(widget.stadium == null ? 'Créer' : 'Modifier'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}