import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signUp(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final user = credential.user;
      if (user != null) {
        try {
          // Initialize user document with studytime: null
          await _firestore.collection('users').doc(user.uid).set({
            'studytime': null,
          }, SetOptions(merge: true));

          // Save FCM token if available
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await _firestore.collection('users').doc(user.uid).set({
              'fcmToken': token,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }
      return user;
    } catch (e) {
      print("Sign up error: $e");
      return null;
    }
  }

  Future<User?> signIn(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final user = credential.user;
      if (user != null) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await _firestore.collection('users').doc(user.uid).set({
              'fcmToken': token,
            }, SetOptions(merge: true));
          }
          // Ensure studytime field exists; set to null if missing
          final doc = await _firestore.collection('users').doc(user.uid).get();
          final data = doc.data() ?? {};
          if (!data.containsKey('studytime')) {
            await _firestore.collection('users').doc(user.uid).set({
              'studytime': null,
            }, SetOptions(merge: true));
          }
        } catch (_) {}
      }
      return user;
    } catch (e) {
      print("Sign in error: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<User?> get userChanges => _auth.authStateChanges();
}
