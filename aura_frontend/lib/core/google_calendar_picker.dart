import 'package:flutter/material.dart';

Future<DateTime?> showGoogleCalendarDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
  TransitionBuilder? builder,
}) async {
  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return _GoogleCalendarDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate ?? DateTime(2020),
        lastDate: lastDate ?? DateTime(2030),
      );
    },
  );
}

class _GoogleCalendarDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _GoogleCalendarDatePickerDialog({
    Key? key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  }) : super(key: key);

  @override
  State<_GoogleCalendarDatePickerDialog> createState() => _GoogleCalendarDatePickerDialogState();
}

class _GoogleCalendarDatePickerDialogState extends State<_GoogleCalendarDatePickerDialog> {
  late DateTime _selectedDate;
  late DateTime _currentMonth;

  final List<String> _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOffset = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    
    // Calculate total days in month
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final totalDaysInMonth = lastDayOfMonth.day;
    
    final totalCells = firstDayOffset + totalDaysInMonth;
    final rowCount = (totalCells / 7).ceil();
    final gridItems = List<DateTime?>.filled(rowCount * 7, null);
    
    for (int i = 0; i < totalDaysInMonth; i++) {
      gridItems[firstDayOffset + i] = DateTime(_currentMonth.year, _currentMonth.month, i + 1);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF1A73E8), // Google Blue
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatSelectedDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_months[_currentMonth.month - 1]} ${_currentMonth.year}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white70),
                        onPressed: _prevMonth,
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white70),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Weekdays
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekdays.map((day) {
                  return SizedBox(
                    width: 32,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: rowCount * 36.0,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 2,
                    crossAxisSpacing: 2,
                  ),
                  itemCount: gridItems.length,
                  itemBuilder: (context, idx) {
                    final date = gridItems[idx];
                    if (date == null) return const SizedBox();
                    
                    final isSelected = DateUtils.isSameDay(date, _selectedDate);
                    final isToday = DateUtils.isSameDay(date, DateTime.now());
                    final isOutOfRange = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);

                    return GestureDetector(
                      onTap: isOutOfRange
                          ? null
                          : () {
                              setState(() {
                                _selectedDate = date;
                              });
                            },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF1A73E8)
                              : Colors.transparent,
                          border: isToday && !isSelected
                              ? Border.all(color: const Color(0xFF1A73E8), width: 1)
                              : null,
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected || isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isOutOfRange
                                ? Colors.white10
                                : (isSelected
                                    ? Colors.white
                                    : (isToday ? const Color(0xFF1A73E8) : Colors.white70)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Actions
            Padding(
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedDate),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSelectedDate(DateTime date) {
    final List<String> weekDaysFull = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    final List<String> monthsShort = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final dayOfWeek = weekDaysFull[date.weekday - 1];
    final month = monthsShort[date.month - 1];
    return '$dayOfWeek, $month ${date.day}';
  }
}
