import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cache_service.dart';

class GamificationService {
	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;
	final CacheService _cacheService = CacheService();

	DocumentReference<Map<String, dynamic>> _userDoc(String userId) {
		return _firestore.collection('users').doc(userId);
	}

	Future<Map<String, dynamic>> _getGamificationData(String userId) async {
		final doc = await _userDoc(userId).get();
		final data = doc.data() ?? <String, dynamic>{};
		final gamification = Map<String, dynamic>.from(data['gamification'] as Map? ?? {});
		return gamification;
	}

	// Save variable with optimistic update
	Future<void> saveVariable(String userId, String key, int value) async {
		await _cacheService.updateGamificationOptimistic(key, value);
	}

	// Get variable from cache for instant access
	Future<int> getVariable(String userId, String key, {int defaultValue = 0}) async {
		final gamification = _cacheService.getGamificationFromCache();
		final raw = gamification[key];
		if (raw is int) return raw;
		if (raw is num) return raw.toInt();
		return defaultValue;
	}

	// Save string with optimistic update
	Future<void> saveString(String userId, String key, String value) async {
		await _cacheService.updateGamificationOptimistic(key, value);
	}

	// Get string from cache for instant access
	Future<String?> getString(String userId, String key) async {
		final gamification = _cacheService.getGamificationFromCache();
		final raw = gamification[key];
		return raw is String ? raw : null;
	}

	// Save DateTime with optimistic update
	Future<void> saveDateTime(String userId, String key, DateTime value) async {
		await _cacheService.updateGamificationOptimistic(key, value.toIso8601String());
	}

	// Get DateTime from cache for instant access
	Future<DateTime?> getDateTime(String userId, String key) async {
		final s = await getString(userId, key);
		if (s == null) return null;
		return DateTime.tryParse(s);
	}

	// Increment with optimistic update
	Future<int> increment(String userId, String key, int by) async {
		return await _cacheService.incrementGamificationOptimistic(key, by);
	}

	String? get currentUserId => _auth.currentUser?.uid;
}
