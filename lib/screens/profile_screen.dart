import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/membership.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

// Pantalla de perfil: quién eres tú. Separada de Ajustes, que es
// configuración de la app. Aquí viven tu foto, tu nombre y tus datos.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  // Diámetro del avatar de perfil (grande: es el protagonista de la pantalla).
  static const double _avatarSize = 160;

  // No es 'final': tras editar nombre o foto lo reasignamos para recargar.
  late Future<({Membership membership, Group group, AppUser? user})?>
  _profileFuture;

  bool _uploadingPhoto = false; // mientras sube, el avatar muestra spinner

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<({Membership membership, Group group, AppUser? user})?>
  _loadProfile() async {
    final uid = _authService.currentUser!.uid;
    final data = await _firestoreService.getUserMembershipAndGroup(uid);
    if (data == null) return null;
    final user = await _firestoreService.getUser(uid);
    return (membership: data.membership, group: data.group, user: user);
  }

  void _reload() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  // Hoja inferior para elegir el origen de la foto: cámara o galería.
  Future<void> _pickPhoto(Membership membership) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, color: AppTheme.kGreen),
              title: const Text('Hacer una foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.kGreen),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return; // cerró la hoja sin elegir

    // Acotamos la resolución ANTES de pasarla al recortador: uCrop carga la
    // imagen entera en memoria y una foto de móvil a resolución completa
    // (decenas de MP) puede tumbar la app. 1600px es amplio de sobra para
    // encuadrar con calidad, y el recorte final baja a 512.
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return; // canceló la cámara/galería

    // Recorte cuadrado 1:1 bloqueado: el avatar siempre se pinta en círculo,
    // así que un cuadrado encaja perfecto al recortarse en redondo. El propio
    // recortador entrega la imagen final a 512px y comprimida.
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      maxWidth: 512,
      maxHeight: 512,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 70,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        // Android (uCrop): tematizado con la paleta de la app.
        AndroidUiSettings(
          toolbarTitle: 'Recortar foto',
          toolbarColor: AppTheme.kGreen,
          toolbarWidgetColor: AppTheme.kCreamCard,
          statusBarColor: AppTheme.kGreenDark,
          backgroundColor: AppTheme.kInk,
          activeControlsWidgetColor: AppTheme.kGreen,
          lockAspectRatio: true, // cuadrado fijo, sin desbloquear proporción
          hideBottomControls: true, // sin ajustes extra: encuadrar y listo
        ),
        // iOS (TOCropViewController): cuadrado fijo también.
        IOSUiSettings(
          title: 'Recortar foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );

    if (cropped == null) return; // canceló el recorte

    setState(() => _uploadingPhoto = true);

    try {
      await _firestoreService.uploadProfilePhoto(
        userId: membership.userId,
        groupId: membership.groupId,
        imageFile: File(cropped.path),
      );
      _reload(); // recarga para mostrar la foto nueva
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo subir la foto.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  // Diálogo para cambiar el nombre propio. Mismo patrón que el de los
  // fantasmas, para no inventar una interacción nueva.
  Future<void> _editName(Membership membership) async {
    final controller = TextEditingController(text: membership.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar mi nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu nombre se actualizará también en los partidos '
              'en los que apareces.',
              style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return; // no permitimos nombre vacío
              Navigator.of(context).pop(text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    if (newName == membership.displayName) return;

    try {
      await _firestoreService.updateUserName(
        userId: membership.userId,
        groupId: membership.groupId,
        newName: newName,
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar el nombre.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body:
          FutureBuilder<({Membership membership, Group group, AppUser? user})?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(
                  child: Text('No se pudieron cargar tus datos.'),
                );
              }

              final membership = snapshot.data!.membership;
              final group = snapshot.data!.group;
              final user = snapshot.data!.user;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // --- Avatar tocable, con la foto o el placeholder ---
                    _buildAvatar(membership),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _uploadingPhoto
                          ? null
                          : () => _pickPhoto(membership),
                      icon: const Icon(Icons.photo_camera, size: 18),
                      label: const Text('Cambiar foto'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      membership.displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      membership.roleLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Datos ---
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.person_outline,
                              color: AppTheme.kGreen,
                            ),
                            title: const Text('Nombre'),
                            subtitle: Text(membership.displayName),
                            trailing: const Icon(Icons.edit_outlined, size: 20),
                            onTap: () => _editName(membership),
                          ),
                          if (user != null)
                            ListTile(
                              leading: const Icon(
                                Icons.mail_outline,
                                color: AppTheme.kGreen,
                              ),
                              title: const Text('Correo'),
                              subtitle: Text(user.email),
                            ),
                          ListTile(
                            leading: const Icon(
                              Icons.groups_outlined,
                              color: AppTheme.kGreen,
                            ),
                            title: const Text('Grupo'),
                            subtitle: Text(group.name),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Avatar circular: muestra la foto si existe, si no la inicial. Mientras
  // sube una foto nueva, un spinner encima. Tocarlo abre el selector.
  Widget _buildAvatar(Membership membership) {
    final photoUrl = membership.photoUrl;
    final initial = membership.displayName.isNotEmpty
        ? membership.displayName[0].toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _uploadingPhoto ? null : () => _pickPhoto(membership),
      child: Container(
        width: _avatarSize,
        height: _avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.kCreamCard,
          border: Border.all(color: AppTheme.kGreen, width: 4),
          boxShadow: [
            BoxShadow(
              color: AppTheme.kInk.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          // Si hay foto, la ponemos como fondo del círculo.
          image: photoUrl != null
              ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: _uploadingPhoto
            ? const CircularProgressIndicator(color: AppTheme.kGreen)
            : (photoUrl == null
                  ? Text(
                      initial,
                      style: TextStyle(
                        fontSize: _avatarSize * 0.4,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.kGreen,
                      ),
                    )
                  : null),
      ),
    );
  }
}
