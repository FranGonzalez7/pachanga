import 'package:flutter/material.dart';
import '../services/firestore_service.dart';
import '../models/match.dart';

class CreateMatchSheet extends StatefulWidget {
  final String groupId;
  final String createdBy;
  final VoidCallback onMatchCreated;
  // Si viene un partido, el formulario está en modo EDICIÓN.
  // Si es null, en modo CREACIÓN.
  final Match? matchToEdit;

  const CreateMatchSheet({
    super.key,
    required this.groupId,
    required this.createdBy,
    required this.onMatchCreated,
    this.matchToEdit,
  });

  @override
  State<CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<CreateMatchSheet> {
  final FirestoreService _firestoreService = FirestoreService();

  int _teamSize = 5;
  DateTime? _selectedDate;
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  // ¿Estamos editando? (hay un partido de partida)
  bool get _isEditing => widget.matchToEdit != null;

  @override
  void initState() {
    super.initState();
    // En modo edición, precargamos los datos del partido existente.
    final match = widget.matchToEdit;
    if (match != null) {
      _teamSize = match.teamSize;
      _selectedDate = match.scheduledAt;
      _locationController.text = match.location;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedDate != null
          ? TimeOfDay.fromDateTime(_selectedDate!)
          : TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Elige una fecha y hora.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // Modo edición: actualizamos lugar, fecha y hora del partido.
        await _firestoreService.updateMatchDetails(
          matchId: widget.matchToEdit!.matchId,
          scheduledAt: _selectedDate!,
          location: _locationController.text.trim(),
        );
      } else {
        // Modo creación: creamos el partido nuevo.
        await _firestoreService.createMatch(
          groupId: widget.groupId,
          type: '${_teamSize}v$_teamSize',
          teamSize: _teamSize,
          scheduledAt: _selectedDate!,
          createdBy: widget.createdBy,
          location: _locationController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        widget.onMatchCreated(); // avisa para refrescar
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'No se pudo editar el partido.'
                  : 'No se pudo crear el partido.',
            ),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isEditing ? 'Editar partido' : 'Nuevo partido',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Text('Tipo de partido'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [5, 6, 7].map((size) {
              final isSelected = _teamSize == size;
              return ChoiceChip(
                label: Text('${size}v$size'),
                selected: isSelected,
                // En edición, el tipo no se puede cambiar (regeneraría slots).
                onSelected: _isEditing
                    ? null
                    : (_) => setState(() => _teamSize = size),
              );
            }).toList(),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 4),
            Text(
              'El tipo no se puede cambiar al editar.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const SizedBox(height: 20),
          const Text('Fecha y hora'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(
              _selectedDate == null
                  ? 'Seleccionar fecha y hora'
                  : _formatDate(_selectedDate!),
            ),
            onPressed: _pickDateTime,
          ),
          const SizedBox(height: 20),
          const Text('Lugar'),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ej: Polideportivo de la Vega',
              prefixIcon: Icon(Icons.place_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _submit,
                    child: Text(
                      _isEditing ? 'Guardar cambios' : 'Crear partido',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
