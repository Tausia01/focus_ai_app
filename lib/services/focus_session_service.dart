import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/focus_session.dart';
import '../models/focus_session_summary.dart';

class FocusSessionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> saveSessionResult({
    required FocusSession session,
    required int distractionCount,
    required bool wasSuccessful,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final startedAt = session.startTime ?? DateTime.now();
    final completedAt = DateTime.now();

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('focusSessions')
        .add({
      'blockedApps': session.blockedApps,
      'durationMinutes': session.duration.inMinutes,
      'durationSeconds': session.duration.inSeconds,
      'distractionCount': distractionCount,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(completedAt),
      'status': wasSuccessful ? 'completed' : 'failed',
      'successful': wasSuccessful,
    });
  }

  Stream<FocusSessionSummary> focusSessionSummaryStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const FocusSessionSummary.empty());
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('focusSessions')
        .snapshots()
        .map((snapshot) {
      var totalDistractions = 0;
      var completedSessions = 0;
      var failedSessions = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawDistractions = data['distractionCount'];
        if (rawDistractions is int) {
          totalDistractions += rawDistractions;
        } else if (rawDistractions is num) {
          totalDistractions += rawDistractions.toInt();
        }

        final status = (data['status'] as String?)?.toLowerCase();
        final successfulFlag = data['successful'];
        bool wasSuccessful = true;

        if (status == 'failed') {
          wasSuccessful = false;
        } else if (status == 'completed') {
          wasSuccessful = true;
        } else if (successfulFlag is bool) {
          wasSuccessful = successfulFlag;
        }

        if (wasSuccessful) {
          completedSessions++;
        } else {
          failedSessions++;
        }
      }

      return FocusSessionSummary(
        totalSessions: snapshot.docs.length,
        completedSessions: completedSessions,
        failedSessions: failedSessions,
        totalDistractions: totalDistractions,
      );
    });
  }
}


