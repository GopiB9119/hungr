import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungr/core/services/firebase_service.dart';
import 'package:hungr/core/services/local_storage_service.dart';

void main() {
  test('Android cache and code_cache reopen the original private store; shared roots are ignored', () {
    const root = '/data/user/10/fixture.app';
    const original = '$root/app_flutter/hungr_local_store.json';
    final existing = <String>{original};
    String? resolve(String temp, {String? link}) => androidStorePath(temp,
        exists: existing.contains, isSafe: (path) => path != link);

    expect(resolve('$root/cache'), original);
    expect(resolve('$root/code_cache'), original);
    const fallback = '$root/files/hungr_local_store.json';
    existing.add(fallback);
    expect(resolve('$root/code_cache', link: original), fallback);
    existing.remove(original);
    expect(resolve('$root/cache'), fallback);
    expect(resolve('/storage/emulated/0/fixture.app/cache'), isNull);
    expect(resolve('/data/local/tmp'), isNull);
  });

  test('offline restoration is limited to an acknowledged matching customer profile', () async {
    final data = customerProfileWrite(uid: 'customer-a', verifiedPhone: 'fixture-a',
        existing: null, serverTime: Timestamp.fromMillisecondsSinceEpoch(0), name: 'Customer A');
    final reads = <Source>[];
    var pending = false;
    var failure = 'unavailable';
    Map<String, dynamic>? cached = data;
    Future<CustomerProfile?> restore() => loadVerifiedProfile(uid: 'customer-a', phone: 'fixture-a',
        read: (source) async {
          reads.add(source);
          if (source == Source.server) throw FirebaseException(plugin: 'fixture', code: failure);
          return (data: cached, pending: pending);
        });

    expect((await restore())!.name, 'Customer A');
    expect(reads, [Source.server, Source.cache]);
    pending = true;
    await expectLater(restore(), throwsStateError);
    pending = false;
    cached = {...data, 'uid': 'customer-b'};
    await expectLater(restore(), throwsStateError);
    cached = {...data, 'phoneNumber': 'fixture-b'};
    await expectLater(restore(), throwsStateError);
    cached = null;
    await expectLater(restore(), throwsA(isA<FirebaseException>()));
    cached = data;
    failure = 'permission-denied';
    reads.clear();
    await expectLater(restore(), throwsA(isA<FirebaseException>()));
    expect(reads, [Source.server]);
    reads.clear();
    expect(await loadVerifiedProfile(uid: 'customer-a', phone: 'fixture-a', read: (source) async {
      reads.add(source);
      return (data: null, pending: false);
    }), isNull);
    expect(reads, [Source.server]);
  });
}
