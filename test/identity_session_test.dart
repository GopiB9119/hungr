import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungr/core/router/identity_redirect.dart';
import 'package:hungr/core/router/route_names.dart';
import 'package:hungr/core/services/firebase_service.dart';
import 'package:hungr/core/services/local_storage_service.dart';
import 'package:hungr/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:hungr/features/onboarding/data/cluster_repository.dart';
import 'package:hungr/features/onboarding/domain/cluster_model.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/customer_dashboard_viewmodel.dart';

const _gate = DeliveryCluster(id: 'selected-gate', name: 'Selected gate', addressZone: 'Zone A',
    landmark: 'Desk A', currentSubscribers: 3, maxCapacity: 8, latitude: 0, longitude: 0);
final _serverTime = Timestamp.fromMillisecondsSinceEpoch(0);

class _User extends Fake implements User {
  _User(this.uid, this.phoneNumber);
  @override
  final String uid;
  @override
  final String? phoneNumber;
  @override
  bool get isAnonymous => false;
}

class _Backend extends Fake implements FirebaseService {
  @override
  User? currentUser;
  @override
  Stream<User?> get authStateChanges => Stream.value(currentUser);
  User? result = _User('customer-a', 'fixture-phone');
  late void Function(String, int?) sent;
  late Future<void> Function(PhoneAuthCredential) instant;
  final writes = <Map<String, Object>>[];
  final documents = <String, Map<String, dynamic>>{};
  bool rejectRead = false;
  Completer<void>? commit;
  bool rejectProfile = false;
  bool rejectSignOut = false;
  int signIns = 0;

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String, int?) onCodeSent,
    required void Function(String) onError,
    required Future<void> Function(PhoneAuthCredential) onAutoVerified,
    int? resendToken,
  }) async {
    sent = onCodeSent;
    instant = onAutoVerified;
  }

  @override
  Future<User?> signIn(PhoneAuthCredential credential) async {
    signIns++;
    return currentUser = result;
  }

  @override
  Future<CustomerProfile?> readCustomerProfile(User user) async {
    if (rejectRead) throw StateError('Fixture unavailable');
    return verifiedCustomerProfile(documents[user.uid], uid: user.uid, phone: user.phoneNumber!);
  }

  @override
  Future<CustomerProfile> syncUserProfile({
    required User user,
    String? name,
    String? clusterName,
  }) async {
    if (rejectProfile) throw StateError('Fixture write rejected');
    if (commit != null) await commit!.future;
    final existing = documents[user.uid];
    final patch = customerProfileWrite(uid: user.uid, verifiedPhone: user.phoneNumber!,
        existing: existing, serverTime: _serverTime,
        name: name, clusterName: clusterName);
    documents[user.uid] = {...?existing, ...patch};
    writes.add(patch);
    return (name: patch['name'] as String, clusterName: patch['clusterName'] as String);
  }

  @override
  Future<void> signOut() async {
    if (rejectSignOut) throw StateError('Fixture sign-out rejected');
    currentUser = null;
  }
}

void main() {
  late LocalStorageService cache;
  late _Backend backend;
  late ProviderContainer container;
  late List<String> events;
  late List<String> errors;

  setUp(() {
    cache = LocalStorageService.inMemory();
    backend = _Backend();
    events = [];
    errors = [];
  });

  AuthViewModel launch([FirebaseService? service]) {
    container = ProviderContainer(overrides: [
      identityBackendProvider.overrideWithValue(service ?? backend),
      identityStorageProvider.overrideWithValue(cache),
      customerDashboardProvider.overrideWith((ref) => CustomerDashboardViewModel(storage: cache)),
    ]);
    addTearDown(container.dispose);
    return container.read(authProvider.notifier);
  }

  Future<void> request(AuthViewModel auth) => auth.requestOtp(
        phone: 'fixture-phone',
        name: ' Customer A ',
        onCodeSent: () => events.add('enter-code'),
        onVerified: () => events.add('verified'),
        onError: errors.add,
      );
  Future<void> submit(AuthViewModel auth) => auth.verifyCode(
        smsCode: '000000', // Consumed only by the local fake.
        onSuccess: () => events.add('verified'),
        onError: errors.add,
      );
  PhoneAuthCredential credential() => PhoneAuthProvider.credential(
        verificationId: 'offline-fixture', smsCode: '000000',
      );

  test('unavailable Firebase does not restore cached access or issue an SMS challenge', () async {
    await cache.bindCustomer('previous-customer', profileGate: '');
    await cache.saveVerifiedGate('previous-customer', _gate);
    // No Firebase initialization: the production unavailable-service path cannot send SMS.
    expect(FirebaseService.instance.isInitialized, isFalse);
    final auth = launch(FirebaseService.instance);
    expect(await identityRedirect(RouteNames.ticketCalendar, auth), RouteNames.phoneAuth);
    expect(await identityRedirect(RouteNames.legalPolicy, auth), isNull);
    await request(auth);
    expect(errors.single, contains('unavailable'));
    expect(await identityRedirect(RouteNames.otpVerify, auth), RouteNames.phoneAuth);
    await submit(auth);
    expect(errors.last, contains('Request a new verification code'));
    expect(events, isEmpty);
    expect(container.read(authProvider).isAuthenticated, isFalse);
  });

  test('SMS receipt alone is not a session; sign-in and gate selection use the verified profile', () async {
    final auth = launch();
    await request(auth);
    backend.sent('offline-fixture', null);
    expect(events, ['enter-code']);
    expect(await identityRedirect(RouteNames.otpVerify, auth), isNull);
    expect(await identityRedirect(RouteNames.profile, auth), RouteNames.phoneAuth);
    await submit(auth);
    expect(errors, isEmpty);
    expect(events, ['enter-code', 'verified']);
    expect(await identityRedirect(RouteNames.profile, auth), isNull);
    for (final path in [RouteNames.storefront, RouteNames.passCheckout, RouteNames.shopDetails]) {
      expect(await identityRedirect(path, auth), RouteNames.clusterSelection);
    }
    expect(backend.writes.single, {
      'uid': 'customer-a', 'role': 'customer', 'name': 'Customer A',
      'phoneNumber': 'fixture-phone', 'clusterName': '',
      'createdAt': _serverTime, 'updatedAt': _serverTime,
    });
    // Close the selection listener before the remote commit finishes.
    final watching = container.listen(selectedClusterProvider, (previous, next) {});
    backend.commit = Completer<void>();
    final saving = auth.updateGate(_gate);
    watching.close();
    expect(await identityRedirect(RouteNames.passCheckout, auth), RouteNames.clusterSelection);
    backend.commit!.complete();
    await saving;
    expect(await identityRedirect(RouteNames.passCheckout, auth), isNull);
    expect(container.read(selectedClusterProvider), same(_gate));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(customerDashboardProvider).selectedCluster.toMap(), _gate.toMap());
    expect(await cache.getSavedCluster(), {
      'id': _gate.id, 'name': _gate.name, 'zone': _gate.addressZone, 'landmark': _gate.landmark,
    });
    // Updating an existing profile must not replace its role or creation time.
    expect(backend.writes.last, {
      'name': 'Customer A', 'phoneNumber': 'fixture-phone',
      'clusterName': 'Selected gate', 'updatedAt': _serverTime,
    });
    final restored = launch();
    expect(await identityRedirect(RouteNames.phoneAuth, restored), RouteNames.storefront);
    expect(container.read(authProvider).gate!.toMap(), _gate.toMap());
    expect(container.read(customerDashboardProvider).selectedCluster.toMap(), _gate.toMap());
    expect(container.read(authProvider).userName, 'Customer A');
    backend.documents['customer-a']!['clusterName'] = 'Changed on another device';
    final changed = launch();
    expect(await identityRedirect(RouteNames.passCheckout, changed), RouteNames.clusterSelection);
    expect(await cache.getSavedCluster(), isNull);
  });

  test('instant verification finishes once, without an unnecessary OTP screen', () async {
    final auth = launch();
    await request(auth);
    final completion = backend.instant(credential());
    backend.sent('late-fixture', null);
    await completion;
    backend.sent('late-fixture', null);
    expect(events, ['verified']);
    expect(errors, isEmpty);
    expect(backend.writes.single['uid'], 'customer-a');
    expect(backend.signIns, 1);
    expect(await identityRedirect(RouteNames.clusterSelection, auth), isNull);
  });

  test('a cancelled request cannot complete a later sign-in', () async {
    final auth = launch();
    await request(auth);
    backend.sent('first-fixture', null);
    final oldCompletion = backend.instant;
    auth.cancelChallenge();
    await request(auth);
    await oldCompletion(credential());
    expect(backend.signIns, 0);
    backend.sent('second-fixture', null);
    await backend.instant(credential());
    expect(events, ['enter-code', 'enter-code', 'verified']);
    expect(backend.writes, hasLength(1));
  });

  test('a credential without the requested phone user or without profile sync cannot finish', () async {
    final auth = launch();
    await request(auth);
    backend.sent('offline-fixture', null);
    for (final result in [null, _User('different-customer', 'different-fixture')]) {
      backend.result = result;
      await submit(auth);
      expect(auth.hasVerifiedSession, isFalse);
      expect(backend.currentUser, isNull);
    }
    backend.result = _User('customer-a', 'fixture-phone');
    backend.rejectProfile = true;
    await submit(auth);
    expect(errors, hasLength(3));
    expect(errors.last, contains('profile'));
    expect(events, ['enter-code']);
    expect(container.read(authProvider).isLoading, isFalse);
    expect(backend.currentUser, isNull);
    expect(backend.writes, isEmpty);
  });

  test('restoration binds the SDK customer; confirmed logout wipes customer preferences', () async {
    await cache.bindCustomer('customer-a', profileGate: '');
    await cache.saveVerifiedGate('customer-a', _gate);
    await cache.saveReferralState(count: 4, isClaimed: true);
    backend.currentUser = _User('customer-b', 'fixture-b');
    backend.documents['customer-b'] = customerProfileWrite(uid: 'customer-b', verifiedPhone: 'fixture-b',
        existing: null, serverTime: _serverTime, name: 'Customer B', clusterName: _gate.name);
    final auth = launch();
    expect(await identityRedirect(RouteNames.profile, auth), isNull);
    final restored = container.read(authProvider);
    expect(restored.phoneNumber, 'fixture-b');
    expect(restored.userName, 'Customer B');
    expect(restored.gate, isNull);
    expect(await identityRedirect(RouteNames.phoneAuth, auth), RouteNames.clusterSelection);
    expect((await cache.getReferralState())['isClaimed'], isFalse);

    await auth.updateGate(_gate);
    await cache.savePassState(hasActivePass: true, tier: 'routine7Day', mealsRemaining: 2,
        totalMeals: 7, tomorrowCombo: 'A');
    await cache.saveReferralState(count: 2, isClaimed: true);
    backend.rejectSignOut = true;
    expect(await auth.logout(), isFalse);
    expect(auth.hasVerifiedSession, isTrue);
    backend.rejectSignOut = false;
    expect(await auth.logout(), isTrue);
    expect(await identityRedirect(RouteNames.profile, auth), RouteNames.phoneAuth);
    expect(container.read(authProvider).phoneNumber, isEmpty);
    expect(await cache.getSavedCluster(), isNull);
    expect(await cache.getSavedPassState(), isNull);
    expect(await cache.getReferralState(), {'count': 0, 'isClaimed': false});
  });

  test('restore never provisions a missing profile; failure can be retried without SMS', () async {
    backend.currentUser = _User('customer-a', 'fixture-phone');
    await cache.bindCustomer('customer-a', profileGate: '');
    await cache.saveVerifiedGate('customer-a', _gate);
    final auth = launch();
    expect(await identityRedirect(RouteNames.storefront, auth), RouteNames.phoneAuth);
    expect(container.read(authProvider).restoreError, contains('not set up'));
    expect(backend.writes, isEmpty);
    backend.rejectRead = true;
    await auth.retryRestore();
    expect(container.read(authProvider).restoreError, contains('retry'));
    expect(auth.hasVerifiedSession, isFalse);
    backend.rejectRead = false;
    backend.documents['customer-a'] = customerProfileWrite(uid: 'customer-a', verifiedPhone: 'fixture-phone',
        existing: null, serverTime: _serverTime, name: 'Recovered customer', clusterName: _gate.name);
    await auth.retryRestore();
    expect(auth.hasVerifiedSession, isTrue);
    expect(container.read(authProvider).userName, 'Recovered customer');
    // The remote name is not a complete local selection on its own.
    expect(await identityRedirect(RouteNames.storefront, auth), RouteNames.clusterSelection);
    expect(backend.signIns, 0);
    expect(backend.writes, isEmpty);
  });
}
