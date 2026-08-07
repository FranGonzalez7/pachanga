import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'player_avatar.dart';

// Diálogo con las cartas de jugador (estilo cromo), deslizables horizontalmente.
class PlayerCardDialog extends StatefulWidget {
  final List<Membership> players;
  final int initialIndex;
  // Quien mira: su rol decide qué acciones ve en cada cromo (un bool ya no
  // basta desde los co-capitanes; las reglas dependen de QUIÉN mira a quién).
  final Membership viewer;
  final VoidCallback? onChanged;

  const PlayerCardDialog({
    super.key,
    required this.players,
    required this.initialIndex,
    required this.viewer,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Membership> players,
    required int initialIndex,
    required Membership viewer,
    VoidCallback? onChanged,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PlayerCardDialog(
        players: players,
        initialIndex: initialIndex,
        viewer: viewer,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<PlayerCardDialog> createState() => _PlayerCardDialogState();
}

class _PlayerCardDialogState extends State<PlayerCardDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.92,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Confirma y elimina a un jugador. La llama la carta desde su botón.
  Future<void> _confirmDelete(Membership player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar jugador'),
        content: Text(
          '¿Seguro que quieres eliminar a ${player.displayName} del grupo? '
          'Sus estadísticas se perderán. Los partidos ya jugados no se '
          'modifican. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestoreService.removeMembership(
      userId: player.userId,
      groupId: player.groupId,
    );

    if (!mounted) return;
    // Cerramos el diálogo entero y avisamos a la lista para que refresque.
    Navigator.of(context).pop();
    widget.onChanged?.call();
  }

  // Pide un nombre nuevo para un fantasma y lo guarda.
  Future<void> _editName(Membership player) async {
    final controller = TextEditingController(text: player.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.of(context).pop(text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty) return;
    if (newName == player.displayName) return; // sin cambios, no hacemos nada

    await _firestoreService.updateGhostName(
      userId: player.userId,
      groupId: player.groupId,
      newName: newName,
    );

    if (!mounted) return;
    // Cerramos y avisamos a la lista para que recargue con el nombre nuevo.
    Navigator.of(context).pop();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final viewer = widget.viewer;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(vertical: 40),
      child: SizedBox(
        // Altura ajustada al cromo (520) + holgura para su sombra. Sin la
        // banda externa de antes: así casi no queda zona transparente que no
        // cierre el diálogo al tocarla.
        height: 560,
        child: PageView.builder(
          controller: _pageController,
          // Clip.none: la sombra del cromo (que sobresale abajo) no se recorta.
          clipBehavior: Clip.none,
          itemCount: widget.players.length,
          itemBuilder: (context, index) {
            final player = widget.players[index];
            final isMe = player.userId == viewer.userId;

            // Reglas de borrado:
            // - hay que poder gestionar (capitán o co-capitán), y no borrarse
            //   a uno mismo;
            // - al CAPITÁN no lo borra nadie, nunca;
            // - un co-capitán no borra a otro co-capitán (quitar co-capitanes
            //   es potestad del capitán, y echarlo del grupo lo sería aún más).
            final canDelete =
                viewer.canManage &&
                !isMe &&
                !player.isCaptain &&
                !(viewer.isCoCaptain && player.isCoCaptain);

            // Editar nombre: quien gestiona, y solo si es un fantasma.
            final canEdit = viewer.canManage && player.isGhost;

            return _PlayerCard(
              player: player,
              isMe: isMe,
              canDelete: canDelete,
              canEdit: canEdit,
              onDelete: () => _confirmDelete(player),
              onEdit: () => _editName(player),
            );
          },
        ),
      ),
    );
  }
}

// Una carta individual, estilo cromo de fútbol. Marco ámbar si es el propio
// jugador ("cromo dorado"), verde para el resto. Las acciones de gestión van
// dentro del cromo, sobre el divider.
class _PlayerCard extends StatelessWidget {
  final Membership player;
  final bool isMe;
  final bool canDelete;
  final bool canEdit;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PlayerCard({
    required this.player,
    required this.isMe,
    required this.canDelete,
    required this.canEdit,
    required this.onDelete,
    required this.onEdit,
  });

  // Radio del marco del cromo y hueco alrededor de la foto. La foto redondea
  // con (radio del marco - hueco) para que su curva quede CONCÉNTRICA con la
  // del marco (paralelas, como un paspartú que respeta la forma).
  static const double _frameRadius = 22;
  static const double _photoInset = 14; // hueco entre marco y foto
  static const double _cardHeight =
      520; // altura FIJA: todos los cromos iguales

  @override
  Widget build(BuildContext context) {
    // Marco: ámbar para ti (cromo dorado), verde para los demás.
    final frameColor = isMe ? AppTheme.kAmber : AppTheme.kGreen;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: _cardHeight,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.kCreamCard,
                borderRadius: BorderRadius.circular(_frameRadius),
                border: Border.all(color: frameColor, width: 3),
                // Doble sombra: una difusa y lejana + otra cercana = 3D.
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.kInk.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: AppTheme.kInk.withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildTopZone(),
                  Expanded(child: _buildBottomZone()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Zona superior: foto grande a la izquierda (rectangular, dos esquinas
  // redondeadas siguiendo la curva del marco) y el número de puntos a la
  // derecha. La insignia de rol va superpuesta en la esquina superior de la foto.
  Widget _buildTopZone() {
    // Radio de la foto = radio del marco - hueco => curvas concéntricas.
    final photoCorner = _frameRadius - _photoInset;

    return SizedBox(
      height: 276,
      child: Stack(
        children: [
          // Foto despegada del marco por arriba y por la izquierda (_photoInset).
          // Va en su propio Stack para superponerle la insignia de rol.
          Positioned(
            top: _photoInset,
            left: _photoInset,
            child: SizedBox(
              width: 224,
              height: 262,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(photoCorner),
                      bottomRight: const Radius.circular(55),
                    ),
                    child: SizedBox(
                      width: 224,
                      height: 262,
                      // PlayerAvatar en modo "desnudo" (sin borde): aquí la
                      // forma la da el ClipRRect, no el widget.
                      child: PlayerAvatar(
                        photoUrl: player.photoUrl,
                        name: player.displayName,
                        size: 262,
                        backgroundColor: AppTheme.kGreen,
                        initialColor: Colors.white,
                        fontSize: 88,
                      ),
                    ),
                  ),
                  // Insignia de rol: esquina superior derecha de la foto.
                  Positioned(top: 10, right: 10, child: _roleBadge()),
                ],
              ),
            ),
          ),

          // Número de puntos, arriba a la derecha.
          Positioned(
            top: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.points}',
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.kGreen,
                    height: 1,
                  ),
                ),
                const Text(
                  'PUNTOS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.kAmber,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Zona inferior: nombre y posiciones arriba; abajo, los botones de gestión
  // (si los hay) justo encima del divider verde, y la rejilla de stats.
  // El divider y las stats quedan anclados abajo por igual en TODAS las cartas
  // (spaceBetween los empuja al fondo); los botones solo "crecen" hacia arriba
  // por encima del divider cuando existen. Así stats y divider no se mueven.
  Widget _buildBottomZone() {
    final hasButtons = canEdit || canDelete;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text(
                player.displayName,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.kInk,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              // Posiciones: texto de ejemplo por ahora (aparcadas).
              const Text(
                'Lateral · Delantero',
                style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
              ),
            ],
          ),
          Column(
            children: [
              // Acciones de gestión: a la derecha, justo encima del divider.
              // Círculos con borde verde.
              if (hasButtons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (canEdit)
                        _actionButton(
                          icon: Icons.edit_outlined,
                          color: AppTheme.kInkSoft,
                          onTap: onEdit,
                        ),
                      if (canEdit && canDelete) const SizedBox(width: 10),
                      if (canDelete)
                        _actionButton(
                          icon: Icons.delete_outline,
                          color: Colors.red.shade400,
                          onTap: onDelete,
                        ),
                    ],
                  ),
                ),
              // Divider verde grueso.
              Container(height: 2, color: AppTheme.kGreen),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat(
                    Icons.stadium,
                    'Jugados',
                    '${player.matchesPlayed}',
                    AppTheme.kInkSoft,
                  ),
                  _stat(
                    Icons.military_tech,
                    'Ganados',
                    '${player.wins}',
                    AppTheme.kAmber,
                  ),
                  _stat(
                    Icons.close,
                    'Perdidos',
                    '${player.losses}',
                    AppTheme.kInkSoft,
                  ),
                  _stat(
                    Icons.sports_soccer,
                    'Goles',
                    '${player.goals}',
                    AppTheme.kGreen,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Insignia de rol: capitán (ámbar), co-capitán (plata), fantasma (ámbar)
  // o jugador (sin insignia).
  Widget _roleBadge() {
    late final String label;
    late final IconData? icon;
    late final Color background;

    if (player.isGhost) {
      label = 'SIN CUENTA';
      icon = null;
      background = AppTheme.kAmber;
    } else if (player.isCaptain) {
      label = 'CAPITÁN';
      icon = Icons.star;
      background = AppTheme.kAmber;
    } else if (player.isCoCaptain) {
      // Plata: el paralelo del oro del capitán, como en el podio.
      label = 'CO-CAPITÁN';
      icon = Icons.star;
      background = AppTheme.kSilver;
    } else {
      return const SizedBox.shrink(); // jugador normal: sin insignia
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppTheme.kInk),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.kInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label, String value, Color iconColor) {
    return Column(
      children: [
        Icon(icon, size: 24, color: iconColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppTheme.kInk,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.kInkSoft),
        ),
      ],
    );
  }

  // Botón redondo de acción, solo icono, con borde verde. Dentro del cromo.
  Widget _actionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.kCreamCard,
      shape: const CircleBorder(
        side: BorderSide(color: AppTheme.kGreen, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
