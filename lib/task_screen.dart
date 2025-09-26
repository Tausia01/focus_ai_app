// lib/task_screen.dart

import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'models/task.dart';
import 'services/task_service.dart';
import 'services/gamification_service.dart';
import 'services/cache_service.dart';
import 'widgets/custom_app_bar.dart';

class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _taskService = TaskService();
  final _gamification = GamificationService();
  final _cacheService = CacheService();
  TaskPriority _selectedPriority = TaskPriority.medium;
  DateTime _selectedDate = DateTime.now();
  int _totalPoints = 0;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _addTask() async {
    if (_formKey.currentState!.validate()) {
      final task = Task(
        id: '',
        name: _nameController.text,
        priority: _selectedPriority,
        deadline: _selectedDate,
        completed: false,
      );
      try {
        await _taskService.addTask(task);
        if (!mounted) return;
        Navigator.pop(context);
        _nameController.clear();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e')),
        );
      }
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Task Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a task name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                value: _selectedPriority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedPriority = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Deadline'),
                subtitle: Text(
                  '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addTask,
            child: const Text('Add Task'),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red.shade100;
      case TaskPriority.medium:
        return Colors.orange.shade100;
      case TaskPriority.low:
        return Colors.green.shade100;
    }
  }

  Future<void> _sortTasks(List<Task> tasks, String sortBy) async {
    List<Task> sortedTasks = List.from(tasks);
    if (sortBy == 'priority') {
      sortedTasks.sort((a, b) => b.priority.index.compareTo(a.priority.index));
    } else if (sortBy == 'deadline') {
      sortedTasks.sort((a, b) => a.deadline.compareTo(b.deadline));
    }
    await _taskService.updateTasksOrder(sortedTasks);
  }

  @override
  void initState() {
    super.initState();
    _loadTotalPointsFromCache();
  }

  // Load total points from cache instantly (no await)
  void _loadTotalPointsFromCache() {
    final userId = _gamification.currentUserId;
    if (userId == null) return;
    
    // Get from cache immediately
    final gamificationData = _cacheService.getGamificationFromCache();
    final total = gamificationData['totalPoints'] is int 
        ? gamificationData['totalPoints'] as int 
        : 0;
    
    if (mounted) {
      setState(() {
        _totalPoints = total;
      });
    }
  }

  // Optimistic update for total points - UI updates instantly
  Future<void> _updateTotalPointsOptimistic(int points) async {
    final userId = _gamification.currentUserId;
    if (userId == null) return;

    // Update UI immediately (optimistic)
    setState(() {
      _totalPoints += points;
    });
    
    // Save to cache/Firestore in background
    await _gamification.saveVariable(userId, 'totalPoints', _totalPoints);
    final currentDailyPoints = await _gamification.getVariable(userId, 'dailyPoints');
    await _gamification.saveVariable(userId, 'dailyPoints', currentDailyPoints + points);
  }

  // Build task list with instant loading from cache
  Widget _buildTaskList() {
    // Get initial data from cache instantly
    final initialTasks = _cacheService.getTasksFromCache();
    
    return StreamBuilder<List<Task>>(
      // Use cached data as initial data for instant rendering
      initialData: initialTasks,
      stream: _cacheService.getTasksStream(),
      builder: (context, snapshot) {
        // Show cached data immediately, even if stream hasn't emitted yet
        final tasks = snapshot.data ?? initialTasks;

        if (tasks.isEmpty) {
          return const Center(
            child: Text('No tasks yet. Add some tasks to get started!'),
          );
        }

        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return Card(
              color: _getPriorityColor(task.priority),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Checkbox(
                  value: task.completed,
                  onChanged: (val) async {
                    // Optimistic UI update - happens instantly
                    if (val == true && !task.completed) {
                      await _updateTotalPointsOptimistic(5);
                    }
                    await _taskService.updateTaskCompleted(task.id, val ?? false);
                  },
                ),
                title: Text(
                  task.name,
                  style: TextStyle(
                    decoration: task.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  'Priority: ${task.priority.displayName}\n'
                  'Deadline: ${task.deadline.year}-${task.deadline.month.toString().padLeft(2, '0')}-${task.deadline.day.toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    try {
                      await _taskService.deleteTask(task.id);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting task: $e')),
                      );
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Focus AI',
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              // Get tasks from cache instantly for sorting
              final tasks = _cacheService.getTasksFromCache();
              await _sortTasks(tasks, value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'priority',
                child: const Text('Sort by Priority'),
              ),
              const PopupMenuItem(
                value: 'deadline',
                child: const Text('Sort by Deadline'),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: _buildTaskList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
