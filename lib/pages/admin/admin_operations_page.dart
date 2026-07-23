part of '../../app.dart';

String _adminShortId(Object? value) {
  final text = value?.toString() ?? 'Unknown';
  return text.length > 12 ? '${text.substring(0, 8)}…' : text;
}

String _adminDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null ? '—' : DateFormat.yMMMd().format(parsed.toLocal());
}

class AdminProfilesScreen extends StatefulWidget {
  const AdminProfilesScreen({super.key});

  @override
  State<AdminProfilesScreen> createState() => _AdminProfilesScreenState();
}

class _AdminProfilesScreenState extends State<AdminProfilesScreen> {
  late Future<List<Map<String, dynamic>>> _profiles;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _profiles = MapLovRepository.instance.adminProfiles();

  Future<void> _status(String id, String status) async {
    await MapLovRepository.instance.setAccountStatus(id, status);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Profiles',
    children: [
      const Text('Discovery, completion and verification status.'),
      _AdminFutureList(
        future: _profiles,
        empty: 'No profiles found.',
        builder: (item) => Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Icon(
                item['is_verified'] == true ? Icons.verified : Icons.person,
              ),
            ),
            title: Text(item['first_name'] as String? ?? 'MapLov member'),
            subtitle: Text(
              '${item['city'] ?? 'No city'} • ${item['status']} • '
              '${item['is_discoverable'] == true ? 'Discoverable' : 'Hidden'}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _status(item['id'] as String, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'active', child: Text('Activate')),
                PopupMenuItem(value: 'suspended', child: Text('Suspend')),
                PopupMenuItem(value: 'banned', child: Text('Ban')),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminPhotosScreen extends StatefulWidget {
  const AdminPhotosScreen({super.key});

  @override
  State<AdminPhotosScreen> createState() => _AdminPhotosScreenState();
}

class _AdminPhotosScreenState extends State<AdminPhotosScreen> {
  late Future<List<Map<String, dynamic>>> _photos;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _photos = MapLovRepository.instance.adminPhotos();

  Future<void> _action(Map<String, dynamic> item, String action) async {
    final id = item['id'] as String;
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete this photo?'),
          content: const Text(
            'The database record and stored file will be removed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await MapLovRepository.instance.deleteModeratedPhoto(id);
    } else if (action == 'approve') {
      await MapLovRepository.instance.approveModeratedPhoto(id);
    } else {
      await MapLovRepository.instance.adminVerifyPhoto(id);
    }
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Photos',
    children: [
      const Text('Review, verify or permanently remove profile photos.'),
      _AdminFutureList(
        future: _photos,
        empty: 'No photos found.',
        builder: (item) => Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.photo_outlined)),
            title: Text('Photo ${_adminShortId(item['id'])}'),
            subtitle: Text(
              'Owner ${_adminShortId(item['user_id'])} • ${item['moderation_status']}\n'
              '${item['is_primary'] == true ? 'Profile photo' : 'Album photo'} • '
              '${item['is_verified'] == true ? 'Verified' : 'Not verified'}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _action(item, value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'approve', child: Text('Approve')),
                PopupMenuItem(value: 'verify', child: Text('Verify')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminSuspensionsScreen extends StatefulWidget {
  const AdminSuspensionsScreen({super.key});

  @override
  State<AdminSuspensionsScreen> createState() => _AdminSuspensionsScreenState();
}

class _AdminSuspensionsScreenState extends State<AdminSuspensionsScreen> {
  late Future<List<Map<String, dynamic>>> _profiles;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _profiles = MapLovRepository.instance.adminProfiles().then(
    (all) => all
        .where(
          (item) => item['status'] == 'suspended' || item['status'] == 'banned',
        )
        .toList(),
  );

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Suspensions',
    children: [
      _AdminFutureList(
        future: _profiles,
        empty: 'No suspended accounts.',
        builder: (item) => Card(
          child: ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: Text(item['first_name'] as String? ?? 'MapLov member'),
            subtitle: Text('${item['status']} • hidden from Discover'),
            trailing: FilledButton.tonal(
              onPressed: () async {
                await MapLovRepository.instance.restoreAccount(
                  item['id'] as String,
                  reason: 'Suspension lifted from administrator dashboard',
                );
                if (mounted) setState(_reload);
              },
              child: const Text('Restore'),
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminSubscriptionsScreen extends StatefulWidget {
  const AdminSubscriptionsScreen({super.key});

  @override
  State<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState extends State<AdminSubscriptionsScreen> {
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _items = MapLovRepository.instance.adminSubscriptions();

  Future<void> _change(Map<String, dynamic> item, String tier) async {
    await MapLovRepository.instance.setManualSubscription(
      item['user_id'] as String,
      tier,
      active: tier != 'free',
      reason: 'Administrator dashboard adjustment',
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Subscriptions',
    children: [
      const Text(
        'Store subscriptions remain controlled by Apple or Google. Manual grants last 30 days.',
      ),
      _AdminFutureList(
        future: _items,
        empty: 'No subscription records.',
        builder: (item) => Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(
              '${(item['tier'] ?? 'free').toString().toUpperCase()} • ${item['status']}',
            ),
            subtitle: Text(
              '${item['provider']} • user ${_adminShortId(item['user_id'])}\n'
              'Ends ${_adminDate(item['current_period_end'])}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _change(item, value),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'plus',
                  child: Text('Grant Plus (30 days)'),
                ),
                PopupMenuItem(value: 'vip', child: Text('Grant VIP (30 days)')),
                PopupMenuItem(value: 'free', child: Text('End manual access')),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class AdminPaymentsScreen extends StatelessWidget {
  const AdminPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Payments',
    children: [
      const Text('Server-validated Apple and Google transaction history.'),
      _AdminFutureList(
        future: MapLovRepository.instance.adminPayments(),
        empty: 'No payment transactions.',
        builder: (item) {
          final amount = item['amount_minor'] as num?;
          final amountText = amount == null
              ? 'Amount unavailable'
              : '${(amount / 100).toStringAsFixed(2)} ${item['currency_code'] ?? ''}';
          return Card(
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text('${item['event_type']} • ${item['status']}'),
              subtitle: Text(
                '${item['provider']} • $amountText • ${_adminDate(item['created_at'])}',
              ),
            ),
          );
        },
      ),
    ],
  );
}

class AdminStatisticsScreen extends StatelessWidget {
  const AdminStatisticsScreen({super.key});

  static const _labels = {
    'users': 'Users',
    'discoverable_profiles': 'Discoverable',
    'photos': 'Photos',
    'open_reports': 'Open reports',
    'suspensions': 'Suspensions',
    'active_subscriptions': 'Paid subscriptions',
    'payments': 'Payments',
    'pending_recoveries': 'Recoveries',
  };

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Statistics',
    children: [
      FutureBuilder<Map<String, int>>(
        future: MapLovRepository.instance.adminDashboardStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Unable to load statistics: ${snapshot.error}');
          }
          final values = snapshot.data ?? const {};
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: _labels.entries
                .map(
                  (entry) => _AdminMetric(
                    entry.value,
                    '${values[entry.key] ?? 0}',
                    Icons.analytics_outlined,
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class AdminGlobalNotificationsScreen extends StatefulWidget {
  const AdminGlobalNotificationsScreen({super.key});

  @override
  State<AdminGlobalNotificationsScreen> createState() =>
      _AdminGlobalNotificationsScreenState();
}

class _AdminGlobalNotificationsScreenState
    extends State<AdminGlobalNotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().length < 2 || _body.text.trim().length < 2) return;
    setState(() => _sending = true);
    try {
      final count = await MapLovRepository.instance.sendGlobalNotification(
        _title.text,
        _body.text,
      );
      _title.clear();
      _body.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notification sent to $count active accounts.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Global notifications',
    children: [
      const Text('Send an in-app system notification to every active account.'),
      TextField(
        controller: _title,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Title'),
      ),
      TextField(
        controller: _body,
        maxLength: 1000,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Message'),
      ),
      FilledButton.icon(
        onPressed: _sending ? null : _send,
        icon: const Icon(Icons.send_outlined),
        label: Text(_sending ? 'Sending…' : 'Send notification'),
      ),
    ],
  );
}

class AdminAccountRecoveryScreen extends StatefulWidget {
  const AdminAccountRecoveryScreen({super.key});

  @override
  State<AdminAccountRecoveryScreen> createState() =>
      _AdminAccountRecoveryScreenState();
}

class _AdminAccountRecoveryScreenState
    extends State<AdminAccountRecoveryScreen> {
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() =>
      _requests = MapLovRepository.instance.adminRecoveryRequests();

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Account recovery',
    children: [
      const Text(
        'Cancel a pending deletion and restore the profile when the authentication account still exists.',
      ),
      _AdminFutureList(
        future: _requests,
        empty: 'No account recovery requests.',
        builder: (item) => Card(
          child: ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: Text('User ${_adminShortId(item['user_id'])}'),
            subtitle: Text(
              '${item['status']} • scheduled ${_adminDate(item['scheduled_for'])}',
            ),
            trailing: item['status'] == 'completed'
                ? null
                : FilledButton.tonal(
                    onPressed: () async {
                      await MapLovRepository.instance.restoreAccount(
                        item['user_id'] as String,
                        reason: 'Restored from administrator dashboard',
                      );
                      if (mounted) setState(_reload);
                    },
                    child: const Text('Recover'),
                  ),
          ),
        ),
      ),
    ],
  );
}

class _AdminFutureList extends StatelessWidget {
  const _AdminFutureList({
    required this.future,
    required this.empty,
    required this.builder,
  });

  final Future<List<Map<String, dynamic>>> future;
  final String empty;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Access denied or unavailable: ${snapshot.error}');
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) return Text(empty);
          return Column(children: items.map(builder).toList());
        },
      );
}
