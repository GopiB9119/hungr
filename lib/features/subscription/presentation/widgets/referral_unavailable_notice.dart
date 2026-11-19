import 'package:flutter/material.dart';

class ReferralUnavailableNotice extends StatelessWidget {
  const ReferralUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.info_outline),
      title: Text('Referral rewards unavailable'),
      subtitle: Text('We cannot verify referred orders or issue free passes in this version.'),
    );
  }
}
