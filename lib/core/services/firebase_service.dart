import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/storefront/domain/tiffin_shop_model.dart';

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
    } catch (e) {
      debugPrint('⚠️ [FirebaseService] Firebase init notice: $e');
      // Graceful fallback during offline development or test runs
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
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? resendToken,
  }) async {
    try {
      final authInstance = auth;
      await authInstance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('⚡ [PhoneAuth] Instant auto-verification on Android device');
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          } else {
            await authInstance.signInWithCredential(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('❌ [PhoneAuth] Verification failed: ${e.code} - ${e.message}');
          String message = 'Phone verification failed. Please try again.';
          if (e.code == 'invalid-phone-number') {
            message = 'The provided phone number is not valid.';
          } else if (e.code == 'quota-exceeded') {
            message = 'SMS quota exceeded for today. Please try again later.';
          } else if (e.code == 'too-many-requests') {
            message = 'Too many requests. Please wait a few moments.';
          } else if (e.message != null && e.message!.isNotEmpty) {
            message = e.message!;
          }
          onError(message);
        },
        codeSent: (String verificationId, int? newResendToken) {
          debugPrint('📨 [PhoneAuth] OTP SMS dispatched. Verification ID: $verificationId');
          onCodeSent(verificationId, newResendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          debugPrint('⏰ [PhoneAuth] Auto retrieval timed out for $verificationId');
        },
      );
    } catch (e) {
      debugPrint('❌ [PhoneAuth] Unexpected error: $e');
      onError('Unable to request OTP: $e');
    }
  }

  /// Verifies the 6-digit SMS code and establishes customer session
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
    required String userName,
    required String phoneNumber,
    String? dropGate,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      // Sync user profile to Firestore
      await syncUserProfile(
        uid: user.uid,
        name: userName,
        phone: phoneNumber,
        dropGate: dropGate ?? 'Khammam Gate',
      );
    }

    return userCredential;
  }

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  /// Auth state stream
  Stream<User?> get authStateChanges {
    try {
      return auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Current logged-in user
  User? get currentUser {
    try {
      return auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // 2. USER PROFILE SYNC
  // ==========================================

  Future<void> syncUserProfile({
    required String uid,
    required String name,
    required String phone,
    required String dropGate,
  }) async {
    try {
      final docRef = firestore.collection('users').doc(uid);
      final doc = await docRef.get();
      if (!doc.exists) {
        await docRef.set({
          'uid': uid,
          'name': name,
          'phoneNumber': phone,
          'clusterName': dropGate,
          'role': 'customer',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await docRef.update({
          'name': name,
          'phoneNumber': phone,
          'clusterName': dropGate,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ [FirebaseService] User profile sync notice: $e');
    }
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
          .snapshots()
          .map((snapshot) {
        if (snapshot.docs.isEmpty) {
          debugPrint('ℹ️ [Firestore] No remote shops found, serving standard catalog');
          return TiffinShop.standardShops;
        }
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
          .where('isActive', '==', true)
          .snapshots()
          .map((snapshot) => snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList())
          .handleError((_) => <Map<String, dynamic>>[]);
    } catch (_) {
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }
}
