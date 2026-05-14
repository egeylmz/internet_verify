import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_helper.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  static const _consentKey = 'data_share_consent';
  static const _onboardingKey = 'onboarding_done';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  Future<bool> hasConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_consentKey) ?? false;
  }

  Future<void> setConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentKey, value);
  }

  Future<String?> signInAnonymously() async {
    try {
      final cred = await _auth.signInAnonymously();
      return cred.user?.uid;
    } catch (e) {
      return null;
    }
  }

  String? get currentUid => _auth.currentUser?.uid;

  // Son senkronizasyon tarihini Firestore'dan çeker
  Future<String?> _getLastSyncDate(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data()?['lastSyncDate'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // Belirtilen tarihten sonraki SQLite kayıtlarını Firestore'a yazar (delta sync)
  Future<void> syncUsageData() async {
    final consent = await hasConsent();
    if (!consent) return;

    final uid = currentUid ?? await signInAnonymously();
    if (uid == null) return;

    try {
      final lastSyncDate = await _getLastSyncDate(uid);

      List<Map<String, dynamic>> rows;
      if (lastSyncDate == null) {
        rows = await DatabaseHelper.instance.queryLastNDays(90);
      } else {
        rows = await DatabaseHelper.instance.queryAfterDate(lastSyncDate);
      }

      // Sadece gerçek veri içeren satırları yaz (mobile veya wifi > 0)
      rows = rows.where((r) {
        final m = (r['mobile_mb'] as num?)?.toDouble() ?? 0.0;
        final w = (r['wifi_mb'] as num?)?.toDouble() ?? 0.0;
        return m > 0 || w > 0;
      }).toList();

      if (rows.isEmpty) return;

      final userRef = _db.collection('users').doc(uid);
      final usageRef = userRef.collection('usage');
      final batch = _db.batch();

      for (final row in rows) {
        final date = row['date'] as String;
        batch.set(usageRef.doc(date), {
          'mobile_mb': row['mobile_mb'],
          'wifi_mb': row['wifi_mb'],
          'day_of_week': row['day_of_week'],
        });
      }

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      batch.set(userRef, {
        'lastSyncDate': todayStr,
        'consentDate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (_) {}
  }
}
