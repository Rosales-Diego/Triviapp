import 'package:flutter/material.dart';
import '../data/database_helper.dart';

class CategoryConfigScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryConfigScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryConfigScreen> createState() => _CategoryConfigScreenState();
}

class _CategoryConfigScreenState extends State<CategoryConfigScreen> {
  final _dbHelper = DatabaseHelper.instance;

  String _difficulty = 'medium';
  String _initialDifficulty = 'medium';
  bool _notificationsEnabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  int _frequencyMinutes = 60;
  List<int> _selectedDays = [1, 2, 3, 4, 5];

  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Helper methods to save/read TimeOfDay to/from Database securely
  String _timeToString(TimeOfDay time) => '${time.hour}:${time.minute}';
  TimeOfDay _stringToTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _loadData() async {
    try {
      final savedConfig = await _dbHelper.getCategorySchedule(
        widget.categoryId,
      );

      if (savedConfig != null) {
        _difficulty = savedConfig['difficulty'];
        _initialDifficulty = savedConfig['difficulty'];
        _notificationsEnabled = savedConfig['is_active'] == 1;
        _frequencyMinutes = savedConfig['frequency_minutes'];

        final daysStr = savedConfig['days_of_week'] as String;
        if (daysStr.isNotEmpty) {
          _selectedDays = daysStr.split(',').map(int.parse).toList();
        }

        _startTime = _stringToTime(savedConfig['start_time']);
        _endTime = _stringToTime(savedConfig['end_time']);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _saveConfig() async {
    // 1. Check if the user is trying to change the difficulty
    if (_difficulty != _initialDifficulty) {
      // Check if there is already progress for the previous difficulty
      final progressCount = await _dbHelper.getAnsweredCount(
        widget.categoryId,
        _initialDifficulty,
      );

      if (progressCount > 0) {
        // Show Warning Popup
        final bool? shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Warning: Progress Reset'),
            content: const Text(
              'Changing the difficulty will reset your current progress for this category. '
              'Do you want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false), // Cancel
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                ),
                onPressed: () => Navigator.pop(context, true), // Continue
                child: const Text(
                  'Continue',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );

        // If the user tapped Cancel or dismissed the dialog, STOP saving completely.
        if (shouldContinue != true) {
          return;
        }

        await _dbHelper.setCategoryStarted(widget.categoryId, false);
        await _dbHelper.resetCategoryStats(
          widget.categoryId,
          _initialDifficulty,
        );
      } else {
        // No progress exists, but difficulty changed.
        // Just quietly reset the "started" flag.
        await _dbHelper.setCategoryStarted(widget.categoryId, false);
      }
    }

    // 2. Proceed to save configuration
    _selectedDays.sort();
    final daysString = _selectedDays.join(',');

    await _dbHelper.upsertCategorySchedule(
      categoryId: widget.categoryId,
      difficulty: _difficulty,
      daysOfWeek: daysString,
      startTime: _timeToString(_startTime),
      endTime: _timeToString(_endTime),
      frequencyMinutes: _frequencyMinutes,
      isActive: _notificationsEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully!')),
      );
      Navigator.pop(context); // Return to Dashboard
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Difficulty'),
                  DropdownButton<String>(
                    value: _difficulty,
                    isExpanded: true,
                    items: ['easy', 'medium', 'hard'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _difficulty = val!),
                  ),

                  const Divider(height: 40),

                  SwitchListTile(
                    title: const Text('Enable Notifications'),
                    subtitle: const Text(
                      'Get questions as notifications without opening the app',
                    ),
                    value: _notificationsEnabled,
                    onChanged: (val) =>
                        setState(() => _notificationsEnabled = val),
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (_notificationsEnabled) ...[
                    const SizedBox(height: 16),
                    _buildSectionTitle('Active Days'),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 4.0,
                      children: List.generate(7, (index) {
                        final dayValue = index + 1;
                        return FilterChip(
                          label: Text(_weekDays[index]),
                          selected: _selectedDays.contains(dayValue),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(dayValue);
                              } else {
                                if (_selectedDays.length > 1) {
                                  _selectedDays.remove(dayValue);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'You must select at least one day.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle('Time Range (for selected days)'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (time != null)
                                setState(() => _startTime = time);
                            },
                            // We use context format ONLY for display purposes here
                            child: Text('Start: ${_startTime.format(context)}'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (time != null) setState(() => _endTime = time);
                            },
                            child: Text('End: ${_endTime.format(context)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSectionTitle('Frequency (minutes)'),
                    Slider(
                      value: _frequencyMinutes.toDouble(),
                      min: 15,
                      max: 240,
                      divisions: 15,
                      label: 'Every $_frequencyMinutes min',
                      onChanged: (val) =>
                          setState(() => _frequencyMinutes = val.toInt()),
                    ),
                  ],

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveConfig,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text(
                        'Save Configuration',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
