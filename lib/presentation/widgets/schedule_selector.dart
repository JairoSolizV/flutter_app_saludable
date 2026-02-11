import 'package:flutter/material.dart';

class ScheduleSelector extends StatefulWidget {
  final Function(String) onScheduleChanged;
  
  const ScheduleSelector({super.key, required this.onScheduleChanged});

  @override
  State<ScheduleSelector> createState() => _ScheduleSelectorState();
}

class _ScheduleSelectorState extends State<ScheduleSelector> {
  final Map<String, bool> _selectedDays = {
    'L': false,
    'M': false,
    'X': false,
    'J': false,
    'V': false,
    'S': false,
    'D': false,
  };

  TimeOfDay _startTime = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 20, minute: 0);

  String _buildScheduleString() {
    final selectedDayKeys = _selectedDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedDayKeys.isEmpty) return '';

    final daysStr = selectedDayKeys.join('-');
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
              label: Text(day),
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
