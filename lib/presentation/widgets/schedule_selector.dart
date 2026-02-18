import 'package:flutter/material.dart';

class ScheduleSelector extends StatefulWidget {
  final Function(String) onScheduleChanged;
  final String? initialSchedule;
  
  const ScheduleSelector({
    super.key, 
    required this.onScheduleChanged,
    this.initialSchedule,
  });

  @override
  State<ScheduleSelector> createState() => _ScheduleSelectorState();
}

class _ScheduleSelectorState extends State<ScheduleSelector> {
  late Map<String, bool> _selectedDays;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  
  // Mapa para mostrar nombres de días en español
  static const Map<String, String> _dayNames = {
    'L': 'Lun',
    'M': 'Mar',
    'X': 'Mier',
    'J': 'Jue',
    'V': 'Vie',
    'S': 'Sab',
    'D': 'Dom',
  };
  
  // Mapa inverso para parsear nombres completos a letras simples
  static const Map<String, String> _dayNamesToKey = {
    'Lun': 'L',
    'Mar': 'M',
    'Mier': 'X',
    'Jue': 'J',
    'Vie': 'V',
    'Sab': 'S',
    'Dom': 'D',
  };

  @override
  void initState() {
    super.initState();
    _selectedDays = {
      'L': false,
      'M': false,
      'X': false,
      'J': false,
      'V': false,
      'S': false,
      'D': false,
    };
    
    _startTime = const TimeOfDay(hour: 7, minute: 0);
    _endTime = const TimeOfDay(hour: 20, minute: 0);
    
    // Parsear horario inicial si existe
    if (widget.initialSchedule != null && widget.initialSchedule!.isNotEmpty) {
      _parseSchedule(widget.initialSchedule!);
      // Notificar el horario inicial después de parsearlo
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSchedule();
      });
    }
  }

  void _parseSchedule(String schedule) {
    // Formato esperado: "L-M-X 08:00-18:00" o "Lun-Mar-Mier 08:00-18:00"
    try {
      final parts = schedule.split(' ');
      if (parts.length >= 2) {
        // Parsear días (ej: "L-M-X" o "Lun-Mar-Mier" o "L-M-X-J-V")
        final daysPart = parts[0];
        final dayList = daysPart.split('-');
        for (var day in dayList) {
          // Intentar primero con la letra simple (formato antiguo: L, M, X)
          if (_selectedDays.containsKey(day)) {
            _selectedDays[day] = true;
          } 
          // Si no funciona, intentar con el nombre completo (formato nuevo: Lun, Mar, Mier)
          else if (_dayNamesToKey.containsKey(day)) {
            final key = _dayNamesToKey[day]!;
            if (_selectedDays.containsKey(key)) {
              _selectedDays[key] = true;
            }
          }
        }
        
        // Parsear horario (ej: "08:00-18:00")
        final timePart = parts[1];
        final timeRange = timePart.split('-');
        if (timeRange.length == 2) {
          final startParts = timeRange[0].split(':');
          final endParts = timeRange[1].split(':');
          
          if (startParts.length == 2 && endParts.length == 2) {
            _startTime = TimeOfDay(
              hour: int.parse(startParts[0]),
              minute: int.parse(startParts[1]),
            );
            _endTime = TimeOfDay(
              hour: int.parse(endParts[0]),
              minute: int.parse(endParts[1]),
            );
          }
        }
      }
    } catch (e) {
      // Si hay error al parsear, usar valores por defecto
      debugPrint('Error parsing schedule: $e');
    }
  }

  String _buildScheduleString() {
    final selectedDayKeys = _selectedDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedDayKeys.isEmpty) return '';

    // Convertir letras simples a nombres completos para enviar al backend
    // Formato: "Lun-Mar-Mier 08:00-18:00" (más legible para React admin)
    final daysStr = selectedDayKeys
        .map((key) => _dayNames[key] ?? key)
        .join('-');
    final startStr = '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}';
    final endStr = '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}';

    return '$daysStr $startStr-$endStr';
  }

  void _updateSchedule() {
    widget.onScheduleChanged(_buildScheduleString());
  }

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF7AC142)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _updateSchedule();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Días de Atención',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _selectedDays.keys.map((day) {
            return FilterChip(
              label: Text(_dayNames[day] ?? day),
              selected: _selectedDays[day]!,
              onSelected: (selected) {
                setState(() {
                  _selectedDays[day] = selected;
                  _updateSchedule();
                });
              },
              selectedColor: const Color(0xFF7AC142).withOpacity(0.3),
              checkmarkColor: const Color(0xFF7AC142),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text(
          'Horario de Atención',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(context, true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Color(0xFF7AC142)),
                      const SizedBox(width: 8),
                      Text(
                        '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('a', style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickTime(context, false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 20, color: Color(0xFF7AC142)),
                      const SizedBox(width: 8),
                      Text(
                        '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
