import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class CreateMatchSheet extends StatefulWidget {
  final String groupId;
  final String createdBy;
  final VoidCallback onMatchCreated;

  const CreateMatchSheet({
    super.key,
    required this.groupId,
    required this.createdBy,
    required this.onMatchCreated,
  });

  @override
  State<CreateMatchSheet> createState() => _CreateMatchSheetState();
}

class _CreateMatchSheetState extends State<CreateMatchSheet> {
  final FirestoreService _firestoreService = FirestoreService();

  int _teamSize = 5; // por defecto 5v5
  DateTime? _selectedDate;
  final TextEditingController _locationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _locationController.dispose(); // cerramos el controller al destruir
    super.dispose();
  }

  // Abre el selector de fecha y luego el de hora
  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return; // canceló

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return; // canceló

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
      await _firestoreService.createMatch(
        groupId: widget.groupId,
        type: '${_teamSize}v$_teamSize',
        teamSize: _teamSize,
        scheduledAt: _selectedDate!,
        createdBy: widget.createdBy,
        location: _locationController.text.trim(), // lugar (puede ir vacío)
      );
      if (mounted) {
        Navigator.of(context).pop(); // cierra el modal
        widget.onMatchCreated(); // avisa para refrescar la lista
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el partido.')),
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
          const Text(
            'Nuevo partido',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                onSelected: (_) => setState(() => _teamSize = size),
              );
            }).toList(),
          ),
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
                    child: const Text('Crear partido'),
                  ),
          ),
        ],
      ),
    );
  }

  // Da formato legible a la fecha
  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
