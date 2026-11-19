import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../onboarding/data/cluster_repository.dart';
import '../../../onboarding/domain/cluster_model.dart';
import '../../../storefront/presentation/viewmodels/customer_dashboard_viewmodel.dart';

class AuthState {
  const AuthState({
    this.uid,
    this.userName = '',
    this.phoneNumber = '',
    this.gate,
    this.restoreError,
    this.isLoading = false,
    this.errorMessage,
  });

  final String? uid;
  final String userName;
  final String phoneNumber;
  final DeliveryCluster? gate;
  final String? restoreError;
  final bool isLoading;
  final String? errorMessage;
  bool get isAuthenticated => uid != null;

  AuthState withActivity({bool loading = false, String? error}) => AuthState(
        uid: uid,
        userName: userName,
        phoneNumber: phoneNumber,
        gate: gate,
        restoreError: restoreError,
        isLoading: loading,
        errorMessage: error,
      );
}

class AuthViewModel extends StateNotifier<AuthState> {
  AuthViewModel({
    required FirebaseService firebase,
    required LocalStorageService storage,
    required ValueChanged<DeliveryCluster> onGateCommitted,
  })  : _firebase = firebase,
        _storage = storage,
        _onGateCommitted = onGateCommitted,
        super(const AuthState()) {
    ready = _restore();
  }

  final FirebaseService _firebase;
  final LocalStorageService _storage;
  final ValueChanged<DeliveryCluster> _onGateCommitted;
  late Future<void> ready;
  int _attempt = 0;
  bool _signingIn = false;
  bool _savingGate = false;
  String? _verificationId;
  int? _resendToken;

  bool get hasPendingCode => _verificationId != null;
  bool get hasSavedGate => state.gate != null;

  User? _phoneUser(User? user) {
    if (user == null || user.uid.isEmpty || user.isAnonymous ||
        (user.phoneNumber?.isEmpty ?? true)) {
      return null;
    }
    return user;
  }

  bool get hasVerifiedSession {
    final user = _phoneUser(_firebase.currentUser);
    return user != null && user.uid == state.uid && user.phoneNumber == state.phoneNumber;
  }

  Future<void> _restore() async {
    final attempt = _attempt;
    try {
      final user = _phoneUser(await _firebase.authStateChanges.first);
      if (user != null && user.uid == _firebase.currentUser?.uid) {
        final profile = await _firebase.readCustomerProfile(user);
        if (profile == null) {
          await _storage.clearUserSession();
          state = const AuthState(restoreError:
              'Your customer profile was not set up. Enter your name and verify your phone to finish.');
          return;
        }
        await _acceptProfile(user, profile, attempt);
        return;
      }
      await _storage.clearUserSession();
      state = const AuthState();
    } catch (_) {
      if (attempt == _attempt) {
        state = const AuthState(restoreError:
            'Could not load your customer profile. Check your connection and retry, or sign in again.');
      }
    }
  }

  Future<void> retryRestore() {
    if (state.restoreError == null || state.isLoading) return ready;
    state = state.withActivity(loading: true);
    return ready = _restore();
  }

  void _requireSameUser(User user, int attempt) {
    final current = _phoneUser(_firebase.currentUser);
    if (attempt != _attempt || current?.uid != user.uid || current?.phoneNumber != user.phoneNumber) {
      throw StateError('Session changed.');
    }
  }

  Future<void> _acceptProfile(User user, CustomerProfile profile, int attempt) async {
    _requireSameUser(user, attempt);
    final gate = await _storage.bindCustomer(user.uid, profileGate: profile.clusterName);
    _requireSameUser(user, attempt);
    if (gate != null) _onGateCommitted(gate);
    state = AuthState(uid: user.uid, phoneNumber: user.phoneNumber!, userName: profile.name, gate: gate);
  }

  void _forgetChallenge() {
    _attempt++;
    _verificationId = null;
    _resendToken = null;
  }

  void cancelChallenge() {
    if (state.isAuthenticated) return;
    _forgetChallenge();
    state = const AuthState();
  }

  Future<void> requestOtp({
    required String phone,
    required String name,
    required VoidCallback onCodeSent,
    required VoidCallback onVerified,
    required ValueChanged<String> onError,
    bool resend = false,
  }) async {
    await ready;
    if (_signingIn || state.isLoading || hasVerifiedSession) return;
    final token = resend && phone == state.phoneNumber ? _resendToken : null;
    _forgetChallenge();
    final attempt = _attempt;
    state = AuthState(phoneNumber: phone, userName: name.trim(), isLoading: true);

    void fail(String message) {
      if (attempt != _attempt || _signingIn) return;
      _forgetChallenge();
      state = state.withActivity(error: message);
      onError(message);
    }

    await _firebase.sendOtp(
      phoneNumber: phone,
      resendToken: token,
      onCodeSent: (id, newToken) {
        if (attempt != _attempt || _signingIn || hasPendingCode) return;
        if (id.isEmpty) {
          fail('No verification code was issued. Please try again.');
          return;
        }
        _verificationId = id;
        _resendToken = newToken;
        state = state.withActivity();
        onCodeSent();
      },
      onAutoVerified: (credential) => _complete(credential, attempt, onVerified, onError),
      onError: fail,
    );
  }

  Future<void> verifyCode({
    required String smsCode,
    required VoidCallback onSuccess,
    required ValueChanged<String> onError,
  }) async {
    final id = _verificationId;
    if (id == null) {
      const message = 'Request a new verification code before continuing.';
      state = state.withActivity(error: message);
      onError(message);
      return;
    }
    final credential = PhoneAuthProvider.credential(verificationId: id, smsCode: smsCode);
    await _complete(credential, _attempt, onSuccess, onError);
  }

  Future<void> _complete(PhoneAuthCredential credential, int attempt,
      VoidCallback onVerified, ValueChanged<String> onError) async {
    if (attempt != _attempt || _signingIn) return;
    _signingIn = true;
    state = state.withActivity(loading: true);
    var message = 'Phone verification failed. Request a new code and try again.';
    try {
      final user = _phoneUser(await _firebase.signIn(credential));
      if (user == null || user.uid != _firebase.currentUser?.uid ||
          user.phoneNumber != state.phoneNumber || attempt != _attempt) {
        throw StateError(message);
      }
      message = 'Could not save your customer profile. Please try signing in again.';
      final profile = await _firebase.syncUserProfile(user: user, name: state.userName);
      if (attempt != _attempt) throw StateError('Sign-in cancelled.');
      await _acceptProfile(user, profile, attempt);
      _forgetChallenge();
    } catch (e) {
      if (_firebase.currentUser != null) {
        try {
          await _firebase.signOut();
        } catch (_) {
          message = 'Sign-in did not finish. Please retry.';
        } finally {
          await _storage.clearUserSession();
        }
      }
      if (attempt == _attempt) {
        if (e is FirebaseAuthException && e.code == 'invalid-verification-code') {
          message = 'That verification code is incorrect. Please try again.';
        }
        state = state.withActivity(error: message);
        onError(message);
      }
      return;
    } finally {
      _signingIn = false;
    }
    onVerified();
  }

  Future<void> updateGate(DeliveryCluster gate) async {
    final user = _firebase.currentUser;
    if (!hasVerifiedSession || user == null) throw StateError('Please sign in again.');
    if (gate.id.isEmpty || gate.name.isEmpty) throw StateError('Select a delivery gate.');
    if (_savingGate) throw StateError('Another gate is being saved.');
    final attempt = _attempt;
    _savingGate = true;
    try {
      final profile = await _firebase.syncUserProfile(user: user, clusterName: gate.name);
      _requireSameUser(user, attempt);
      if (profile.clusterName != gate.name) throw StateError('Delivery gate was not confirmed.');
      try {
        await _storage.saveVerifiedGate(user.uid, gate);
      } catch (_) {
        if (attempt == _attempt && hasVerifiedSession && state.uid == user.uid) {
          // The remote gate changed, so the former local gate is no longer valid.
          state = AuthState(uid: user.uid, phoneNumber: user.phoneNumber!, userName: profile.name);
        }
        rethrow;
      }
      _requireSameUser(user, attempt);
      _onGateCommitted(gate);
      state = AuthState(uid: user.uid, phoneNumber: user.phoneNumber!,
          userName: profile.name, gate: gate);
    } finally {
      _savingGate = false;
    }
  }

  Future<bool> logout() async {
    _forgetChallenge();
    try {
      await _firebase.signOut();
    } catch (_) {
      state = state.withActivity(error: 'Could not sign out. Please try again.');
      return false;
    }
    await _storage.clearUserSession();
    state = const AuthState();
    return true;
  }
}

final identityBackendProvider = Provider<FirebaseService>((ref) => FirebaseService.instance);
final identityStorageProvider = Provider<LocalStorageService>((ref) => LocalStorageService.instance);
final authProvider = StateNotifierProvider<AuthViewModel, AuthState>((ref) => AuthViewModel(
  firebase: ref.watch(identityBackendProvider),
  storage: ref.watch(identityStorageProvider),
  onGateCommitted: (gate) {
    ref.read(selectedClusterProvider.notifier).state = gate;
    ref.read(customerDashboardProvider.notifier).updateCluster(gate);
  },
));
