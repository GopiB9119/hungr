import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/storefront/domain/tiffin_shop_model.dart';

typedef CustomerProfile = ({String name, String clusterName});
typedef ProfileSnapshot = ({Map<String, dynamic>? data, bool pending});

CustomerProfile? verifiedCustomerProfile(Map<String, dynamic>? data, {
  required String uid,
  required String phone,
}) {
  if (data == null) return null;
  final name = data['name'];
  final gate = data['clusterName'];
  if (data['uid'] != uid || data['phoneNumber'] != phone ||
      data['createdAt'] is! Timestamp || data['updatedAt'] is! Timestamp ||
      data['role'] != 'customer' || name is! String || name.trim().isEmpty || gate is! String) {
    throw StateError('Customer profile is incomplete.');
  }
  return (name: name, clusterName: gate);
}

Future<CustomerProfile?> loadVerifiedProfile({
  required String uid,
  required String phone,
  required Future<ProfileSnapshot> Function(Source) read,
}) async {
  ProfileSnapshot doc;
  try {
    doc = await read(Source.server);
  } on FirebaseException catch (error) {
    if (error.code != 'unavailable' && error.code != 'deadline-exceeded') rethrow;
    // Never use a cached document in place of a server denial or deletion.
    doc = await read(Source.cache);
    if (doc.data == null) rethrow;
  }
  if (doc.pending) throw StateError('Profile is not confirmed.');
  return verifiedCustomerProfile(doc.data, uid: uid, phone: phone);
}

/// Mutable profile fields for a returning customer; identity/role/creation
/// time are initialized only when the document does not yet exist.
Map<String, Object> customerProfileWrite({
  required String uid,
  required String verifiedPhone,
  required Map<String, dynamic>? existing,
  required Object serverTime,
  String? name,
  String? clusterName,
}) {
  return {
    if (existing == null) ...{
      'uid': uid,
      'role': 'customer',
      'createdAt': serverTime,
    },
    'name': name != null && name.trim().isNotEmpty
        ? name.trim()
        : (existing?['name'] as String?) ?? 'Hungr User',
    'phoneNumber': verifiedPhone,
    'clusterName': clusterName ?? (existing?['clusterName'] as String?) ?? '',
    'updatedAt': serverTime,
  };
}

/// Production Firebase Service powering Authentication, Real-time Firestore sync,
/// and live catalog management for Hungr.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  /// Safely initialize Firebase services
  Future<void> init() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _auth = FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      debugPrint('✅ [FirebaseService] Successfully connected to Firebase');
    } catch (_) {
      debugPrint('[FirebaseService] Firebase unavailable; phone sign-in is disabled.');
      _isInitialized = false;
    }
  }

  // ==========================================
  // 1. PHONE AUTHENTICATION (OTP PIPELINE)
  // ==========================================

  /// Sends 6-digit SMS OTP using Firebase Phone Auth & Google Play Integrity
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String errorMessage) onError,
    required Future<void> Function(PhoneAuthCredential credential) onAutoVerified,
    int? resendToken,
  }) async {
    if (!isInitialized) {
      onError('Phone sign-in is unavailable. Please try again later.');
      return;
    }
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: onAutoVerified,
        verificationFailed: (FirebaseAuthException e) {
          String message = 'Phone verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            message = 'The provided phone number is not valid.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded for today. Please try again later.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please wait a few moments.';
          }
          onError(message);
        },
        codeSent: onCodeSent,
        codeAutoRetrievalTimeout: (_) {}, // Manual entry remains available.
      );
    } catch (_) {
      onError('Unable to request a verification code. Please try again.');
    }
  }

  Future<User?> signIn(PhoneAuthCredential credential) async {
    return (await auth.signInWithCredential(credential)).user;
  }

  Future<void> signOut() => auth.signOut();

  /// Auth state stream
  Stream<User?> get authStateChanges {
    try {
      return isInitialized ? auth.authStateChanges() : Stream.value(null);
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Current logged-in user
  User? get currentUser {
    try {
      return isInitialized ? auth.currentUser : null;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 2. USER PROFILE SYNC
  // ==========================================

  String _verifiedPhone(User user) {
    final phone = user.phoneNumber;
    if (phone == null || phone.isEmpty || user.isAnonymous || currentUser?.uid != user.uid ||
        currentUser?.phoneNumber != phone) {
      throw StateError('A verified phone session is required.');
    }
    return phone;
  }

  Future<CustomerProfile?> readCustomerProfile(User user) async {
    final phone = _verifiedPhone(user);
    final ref = firestore.collection('users').doc(user.uid);
    return loadVerifiedProfile(uid: user.uid, phone: phone, read: (source) async {
      final doc = await ref.get(GetOptions(source: source));
      return (data: doc.data(), pending: doc.metadata.hasPendingWrites);
    });
  }

  Future<CustomerProfile> syncUserProfile({
    required User user,
    String? name,
    String? clusterName,
  }) async {
    final phone = _verifiedPhone(user);
    final docRef = firestore.collection('users').doc(user.uid);
    return firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      final fields = customerProfileWrite(
        uid: user.uid,
        verifiedPhone: phone,
        existing: doc.data(),
        serverTime: FieldValue.serverTimestamp(),
        name: name,
        clusterName: clusterName,
      );
      if (doc.exists) {
        // A mutable-field update cannot repair an incomplete customer identity.
        final existing = doc.data()!;
        if (existing['uid'] != user.uid || existing['role'] != 'customer' || existing['createdAt'] is! Timestamp) {
          throw StateError('Customer profile is incomplete.');
        }
        transaction.update(docRef, fields);
      } else {
        transaction.set(docRef, fields);
      }
      return (name: fields['name'] as String, clusterName: fields['clusterName'] as String);
    });
  }

  // ==========================================
  // 3. REAL-TIME CATALOG & TIFFIN SHOPS
  // ==========================================

  /// Real-time stream of partner tiffin shops from Cloud Firestore
  /// Automatically falls back to standard shops if collection is empty
  Stream<List<TiffinShop>> streamTiffinShops() {
    try {
      return firestore
          .collection('tiffin_shops')
          .snapshots(includeMetadataChanges: true)
          .where((snapshot) => snapshot.docs.isNotEmpty || !snapshot.metadata.isFromCache)
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          return TiffinShop.fromMap(doc.data(), docId: doc.id);
        }).toList();
      }).handleError((error) {
        debugPrint('⚠️ [Firestore stream error]: $error - returning standard catalog');
        return TiffinShop.standardShops;
      });
    } catch (e) {
      debugPrint('⚠️ [Firestore stream exception]: $e');
      return Stream.value(TiffinShop.standardShops);
    }
  }

  /// Stream of active promotional offers & banners
  Stream<List<Map<String, dynamic>>> streamOffers() {
    try {
      return firestore
          .collection('offers')
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList())
          .handleError((_) => <Map<String, dynamic>>[]);
    } catch (_) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }
}
