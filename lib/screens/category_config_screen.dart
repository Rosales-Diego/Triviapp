import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../services/trivia_api_service.dart';

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
  final _apiService = TriviaApiService();
  final _dbHelper = DatabaseHelper.instance;

  String _difficulty = 'medium';
  bool _notificationsEnabled = false;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 21, minute: 0);
  int _frequencyMinutes = 60;

  // List to store selected days (1 = Monday, 7 = Sunday)
  // Default: Monday to Friday
  final List<int> _selectedDays = [1, 2, 3, 4, 5];

  // UI Labels for the days
  final List<String> _weekDays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  bool _isLoadingMetadata = true;
  Map<String, dynamic>? _metadata;

  @override
  void initState() {
    super.initState();
    _fetchAndSyncMetadata();
  }

  Future<void> _fetchAndSyncMetadata() async {
    try {
      final counts = await _apiService.fetchCategoryQuestionCount(
        widget.categoryId,
      );

      await _dbHelper.upsertCategoryMetadata(
        categoryId: widget.categoryId,
        name: widget.categoryName,
        totalEasy: counts['total_easy_question_count'],
        totalMedium: counts['total_medium_question_count'],
        totalHard: counts['total_hard_question_count'],
      );

      if (mounted) {
        setState(() {
          _metadata = counts;
          _isLoadingMetadata = false;
        });
      }
    } catch (e) {
      debugPrint('Error syncing metadata: $e');
      if (mounted) setState(() => _isLoadingMetadata = false);
    }
  }

  void _saveConfig() async {
    // Sort days numerically before saving (e.g., "1,2,5")
    _selectedDays.sort();
    final daysString = _selectedDays.join(',');

    await _dbHelper.upsertCategorySchedule(
      categoryId: widget.categoryId,
      daysOfWeek: daysString,
      startTime: _startTime.format(context),
      endTime: _endTime.format(context),
      frequencyMinutes: _frequencyMinutes,
      isActive: _notificationsEnabled,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.categoryName)),
      body: _isLoadingMetadata
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing questions with server...'),
                ],
              ),
            )
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

                    // --- NEW: Days of the week selector ---
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
                                // Ensure at least one day is always selected
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
