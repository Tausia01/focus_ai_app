import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory caches
  Map<String, List<Task>> _tasksCache = {};
  Map<String, Map<String, dynamic>> _gamificationCache = {};
  
  // Stream controllers for real-time updates
  final Map<String, StreamController<List<Task>>> _taskStreamControllers = {};
  final Map<String, StreamController<Map<String, dynamic>>> _gamificationStreamControllers = {};
  
  // Sync timers
  Timer? _syncTimer;
  bool _isOnline = true;

  String? get currentUserId => _auth.currentUser?.uid;

  // Initialize cache and enable offline persistence
  Future<void> initialize() async {
    // Enable offline persistence
    await _firestore.enableNetwork();
    
    // Start periodic sync
    _startPeriodicSync();
    
    // Listen for auth state changes
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _initializeUserCache(user.uid);
      } else {
        _clearUserCache();
      }
    });
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _syncAllData();
    });
  }

  Future<void> _initializeUserCache(String userId) async {
    // Initialize empty caches
    _tasksCache[userId] = [];
    _gamificationCache[userId] = {};
    
    // Create stream controllers if they don't exist
    _taskStreamControllers[userId] ??= StreamController<List<Task>>.broadcast();
    _gamificationStreamControllers[userId] ??= StreamController<Map<String, dynamic>>.broadcast();
    
    // Load initial data from Firestore
    await _loadTasksFromFirestore(userId);
    await _loadGamificationFromFirestore(userId);
  }

  void _clearUserCache() {
    final userId = currentUserId;
    if (userId != null) {
      _tasksCache.remove(userId);
      _gamificationCache.remove(userId);
      _taskStreamControllers[userId]?.close();
      _gamificationStreamControllers[userId]?.close();
      _taskStreamControllers.remove(userId);
      _gamificationStreamControllers.remove(userId);
    }
  }

  // TASK CACHE METHODS
  Stream<List<Task>> getTasksStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);
    
    _taskStreamControllers[userId] ??= StreamController<List<Task>>.broadcast();
    return _taskStreamControllers[userId]!.stream;
  }

  List<Task> getTasksFromCache() {
    final userId = currentUserId;
    if (userId == null) return [];
    return _tasksCache[userId] ?? [];
  }

  // Optimistic task update
  Future<void> updateTaskCompletedOptimistic(String taskId, bool completed) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Update cache immediately
    final tasks = _tasksCache[userId] ?? [];
    final taskIndex = tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      tasks[taskIndex] = Task(
        id: tasks[taskIndex].id,
        name: tasks[taskIndex].name,
        priority: tasks[taskIndex].priority,
        deadline: tasks[taskIndex].deadline,
        completed: completed,
      );
      _tasksCache[userId] = tasks;
      _taskStreamControllers[userId]?.add(tasks);
    }

    // Sync to Firestore in background
    _syncTaskToFirestore(taskId, {'completed': completed});
  }

  // Optimistic task add
  Future<void> addTaskOptimistic(Task task) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Generate temporary ID
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final taskWithId = Task(
      id: tempId,
      name: task.name,
      priority: task.priority,
      deadline: task.deadline,
      completed: task.completed,
    );

    // Update cache immediately
    final tasks = _tasksCache[userId] ?? [];
    tasks.add(taskWithId);
    _tasksCache[userId] = tasks;
    _taskStreamControllers[userId]?.add(tasks);

    // Sync to Firestore in background
    _syncAddTaskToFirestore(taskWithId);
  }

  // Optimistic task delete
  Future<void> deleteTaskOptimistic(String taskId) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Update cache immediately
    final tasks = _tasksCache[userId] ?? [];
    tasks.removeWhere((task) => task.id == taskId);
    _tasksCache[userId] = tasks;
    _taskStreamControllers[userId]?.add(tasks);

    // Sync to Firestore in background
    _syncDeleteTaskFromFirestore(taskId);
  }

  // GAMIFICATION CACHE METHODS
  Stream<Map<String, dynamic>> getGamificationStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value({});
    
    _gamificationStreamControllers[userId] ??= StreamController<Map<String, dynamic>>.broadcast();
    return _gamificationStreamControllers[userId]!.stream;
  }

  Map<String, dynamic> getGamificationFromCache() {
    final userId = currentUserId;
    if (userId == null) return {};
    return _gamificationCache[userId] ?? {};
  }

  // Optimistic gamification update
  Future<void> updateGamificationOptimistic(String key, dynamic value) async {
    final userId = currentUserId;
    if (userId == null) return;

    // Update cache immediately
    final gamification = _gamificationCache[userId] ?? {};
    gamification[key] = value;
    _gamificationCache[userId] = gamification;
    _gamificationStreamControllers[userId]?.add(gamification);

    // Sync to Firestore in background
    _syncGamificationToFirestore(key, value);
  }

  // Optimistic gamification increment
  Future<int> incrementGamificationOptimistic(String key, int by) async {
    final userId = currentUserId;
    if (userId == null) return 0;

    // Update cache immediately
    final gamification = _gamificationCache[userId] ?? {};
    final current = gamification[key] is int ? gamification[key] as int : 0;
    final next = current + by;
    gamification[key] = next;
    _gamificationCache[userId] = gamification;
    _gamificationStreamControllers[userId]?.add(gamification);

    // Sync to Firestore in background
    _syncIncrementGamificationToFirestore(key, by);

    return next;
  }

  // FIRESTORE SYNC METHODS (Background operations)
  Future<void> _loadTasksFromFirestore(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .orderBy('priority', descending: true)
          .get();

      final tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        return Task.fromMap(data, doc.id);
      }).toList();

      _tasksCache[userId] = tasks;
      _taskStreamControllers[userId]?.add(tasks);
    } catch (e) {
      print('Error loading tasks from Firestore: $e');
    }
  }

  Future<void> _loadGamificationFromFirestore(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};
      final gamification = Map<String, dynamic>.from(data['gamification'] as Map? ?? {});
      
      _gamificationCache[userId] = gamification;
      _gamificationStreamControllers[userId]?.add(gamification);
    } catch (e) {
      print('Error loading gamification from Firestore: $e');
    }
  }

  Future<void> _syncTaskToFirestore(String taskId, Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .update(updates);
    } catch (e) {
      print('Error syncing task to Firestore: $e');
      // Could implement retry logic here
    }
  }

  Future<void> _syncAddTaskToFirestore(Task task) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final docRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .add(task.toMap());
      
      // Update cache with real ID
      final tasks = _tasksCache[userId] ?? [];
      final taskIndex = tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        tasks[taskIndex] = Task(
          id: docRef.id,
          name: task.name,
          priority: task.priority,
          deadline: task.deadline,
          completed: task.completed,
        );
        _tasksCache[userId] = tasks;
        _taskStreamControllers[userId]?.add(tasks);
      }
    } catch (e) {
      print('Error syncing task add to Firestore: $e');
    }
  }

  Future<void> _syncDeleteTaskFromFirestore(String taskId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      print('Error syncing task delete to Firestore: $e');
    }
  }

  Future<void> _syncGamificationToFirestore(String key, dynamic value) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).set({
        'gamification': {key: value},
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error syncing gamification to Firestore: $e');
    }
  }

  Future<void> _syncIncrementGamificationToFirestore(String key, int by) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final ref = _firestore.collection('users').doc(userId);
        final snapshot = await transaction.get(ref);
        final data = snapshot.data() ?? {};
        final gamification = Map<String, dynamic>.from(data['gamification'] as Map? ?? {});
        final current = (gamification[key] is num) ? (gamification[key] as num).toInt() : 0;
        final next = current + by;
        transaction.set(ref, {
          'gamification': {key: next},
        }, SetOptions(merge: true));
      });
    } catch (e) {
      print('Error syncing gamification increment to Firestore: $e');
    }
  }

  Future<void> _syncAllData() async {
    final userId = currentUserId;
    if (userId == null) return;

    await _loadTasksFromFirestore(userId);
    await _loadGamificationFromFirestore(userId);
  }

  void dispose() {
    _syncTimer?.cancel();
    for (var controller in _taskStreamControllers.values) {
      controller.close();
    }
    for (var controller in _gamificationStreamControllers.values) {
      controller.close();
    }
    _taskStreamControllers.clear();
    _gamificationStreamControllers.clear();
  }
}

