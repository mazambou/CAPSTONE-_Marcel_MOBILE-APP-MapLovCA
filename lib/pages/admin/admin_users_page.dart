part of '../../app.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<Map<String, dynamic>>> users;
  String query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => users = MapLovRepository.instance.adminUsers();

  Future<void> _openDetails(Map<String, dynamic> user) async {
    final outcome = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => AdminUserDetailsScreen(initialUser: user),
      ),
    );
    if (!mounted) return;
    setState(_reload);
    if (outcome == 'deleted') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'The account and its stored data were permanently deleted.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'User management',
    children: [
      const Text(
        'Only administrators can change account status. Every action is written to the audit log.',
        style: TextStyle(color: AppColors.grayText),
      ),
      TextField(
        decoration: InputDecoration(
          hintText: context.tr('Search users'),
          prefixIcon: const Icon(Icons.search),
        ),
        onChanged: (value) =>
            setState(() => query = value.trim().toLowerCase()),
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: users,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Access denied or unavailable: ${snapshot.error}');
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Text('No user data is available in demo mode.');
          }
          return Column(
            children: items
                .where(
                  (user) =>
                      '${user['first_name'] ?? ''} ${user['city'] ?? ''} '
                              '${user['status'] ?? ''} ${user['role'] ?? ''} '
                              '${user['id'] ?? ''}'
                          .toLowerCase()
                          .contains(query),
                )
                .map(
                  (user) => Card(
                    child: ListTile(
                      key: Key('admin_user_${user['id']}'),
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(
                        user['first_name'] as String? ?? 'MapLov member',
                      ),
                      subtitle: Text(
                        '${user['city'] ?? ''} • ${user['status']} • ${user['role']}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDetails(user),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

String _adminDateTime(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? '—'
      : DateFormat.yMMMd().add_Hm().format(parsed.toLocal());
}

String _adminDetailValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

class AdminUserDetailsScreen extends StatefulWidget {
  const AdminUserDetailsScreen({super.key, required this.initialUser});

  final Map<String, dynamic> initialUser;

  @override
  State<AdminUserDetailsScreen> createState() => _AdminUserDetailsScreenState();
}

class _AdminUserDetailsScreenState extends State<AdminUserDetailsScreen> {
  late Future<Map<String, dynamic>> _details;
  bool _busy = false;

  String get _userId => widget.initialUser['id'] as String;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _details = _loadDetails();
  }

  Future<Map<String, dynamic>> _loadDetails() async {
    final loaded = await MapLovRepository.instance.adminUserDetails(_userId);
    return {...widget.initialUser, ...loaded};
  }

  Future<bool> _confirmStatus(Map<String, dynamic> user, String status) async {
    final action = switch (status) {
      'active' => 'activate',
      'suspended' => 'suspend',
      _ => 'ban',
    };
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(
              status == 'active'
                  ? Icons.check_circle_outline
                  : Icons.warning_amber_rounded,
              color: status == 'active'
                  ? AppColors.success
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text('Confirm account action'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You are about to $action this specific MapLov account.'),
                const SizedBox(height: 14),
                _AdminTargetIdentity(user: user),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  status == 'active'
                      ? 'Activate'
                      : status == 'suspended'
                      ? 'Suspend'
                      : 'Ban',
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _setStatus(Map<String, dynamic> user, String status) async {
    if (_busy || !await _confirmStatus(user, status)) return;
    setState(() => _busy = true);
    try {
      await MapLovRepository.instance.setAccountStatus(_userId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Account status updated.'))),
      );
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify({required bool photo}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await MapLovRepository.instance.verifyProfile(_userId, photo: photo);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(photo ? 'Photo verified.' : 'Profile verified.'),
          ),
        ),
      );
      setState(_reload);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> user) async {
    if (_busy) return;
    final timing = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Delete this account?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                'Choose whether to erase the account now or schedule permanent deletion in 30 days.',
              ),
            ),
            const SizedBox(height: 14),
            _AdminTargetIdentity(user: user),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Cancel')),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'scheduled'),
            icon: const Icon(Icons.schedule),
            label: Text(context.tr('Schedule in 30 days')),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'immediate'),
            icon: const Icon(Icons.delete_forever),
            label: Text(context.tr('Delete immediately')),
          ),
        ],
      ),
    );
    if (timing == null || !mounted) return;

    final immediate = timing == 'immediate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          immediate ? Icons.warning_amber_rounded : Icons.schedule,
          color: immediate ? Theme.of(context).colorScheme.error : null,
        ),
        title: Text(
          context.tr(
            immediate
                ? 'Permanently delete this account now?'
                : 'Schedule permanent deletion in 30 days?',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(
                immediate
                    ? 'This cannot be undone. All account data and stored files, including the reference selfie, will be erased so the person can register again.'
                    : 'The account will be disabled and hidden now. An administrator can restore it before the 30-day deadline.',
              ),
            ),
            const SizedBox(height: 14),
            _AdminTargetIdentity(user: user),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr(
                immediate ? 'Delete permanently' : 'Schedule deletion',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await MapLovRepository.instance.adminDeleteAccount(
        _userId,
        immediate: immediate,
      );
      if (!mounted) return;
      if (immediate) {
        Navigator.pop(context, 'deleted');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr('Permanent deletion is scheduled in 30 days.'),
          ),
        ),
      );
      setState(_reload);
    } on AdminAccountDeletionException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(_reload);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'User details',
    children: [
      FutureBuilder<Map<String, dynamic>>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                Text('Unable to load user details: ${snapshot.error}'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(_reload),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            );
          }

          final user = snapshot.data ?? widget.initialUser;
          final isOwnAccount =
              user['id'] == MapLovRepository.instance.currentUserId;
          final canManage = user['role'] == 'user' && !isOwnAccount;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.person_outline, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _adminDetailValue(user['first_name']),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(_adminDetailValue(user['email'])),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  label: Text(
                                    _adminDetailValue(user['status']),
                                  ),
                                ),
                                Chip(
                                  label: Text(_adminDetailValue(user['role'])),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _AdminDetailsSection(
                title: 'Identity and contact',
                rows: [
                  _AdminDetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Account ID',
                    value: _adminDetailValue(user['id']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _adminDetailValue(user['email']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone number',
                    value: _adminDetailValue(user['phone']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.cake_outlined,
                    label: 'Date of birth',
                    value: _adminDetailValue(user['date_of_birth']),
                  ),
                ],
              ),
              _AdminDetailsSection(
                title: 'Account details',
                rows: [
                  _AdminDetailRow(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Role',
                    value: _adminDetailValue(user['role']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.shield_outlined,
                    label: 'Account status',
                    value: _adminDetailValue(user['status']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.person_add_alt_outlined,
                    label: 'Account created',
                    value: _adminDateTime(user['auth_created_at']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Profile created',
                    value: _adminDateTime(user['profile_created_at']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.login,
                    label: 'Last sign-in',
                    value: _adminDateTime(user['last_sign_in_at']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.schedule,
                    label: 'Last activity',
                    value: _adminDateTime(user['last_active_at']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.mark_email_read_outlined,
                    label: 'Email confirmed',
                    value: _adminDateTime(user['email_confirmed_at']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.phone_locked_outlined,
                    label: 'Phone confirmed',
                    value: _adminDateTime(user['phone_confirmed_at']),
                  ),
                ],
              ),
              _AdminDetailsSection(
                title: 'Profile details',
                rows: [
                  _AdminDetailRow(
                    icon: Icons.wc_outlined,
                    label: 'Gender',
                    value: _adminDetailValue(user['gender']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.location_city_outlined,
                    label: 'City',
                    value: _adminDetailValue(user['city']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.public_outlined,
                    label: 'Country of residence',
                    value: _adminDetailValue(user['country_name']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.work_outline,
                    label: 'Profession',
                    value: _adminDetailValue(user['profession']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.school_outlined,
                    label: 'Education',
                    value: _adminDetailValue(user['education_level']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.favorite_outline,
                    label: 'Relationship goal',
                    value: _adminDetailValue(user['relationship_goal']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.visibility_outlined,
                    label: 'Discoverable',
                    value: context.tr(
                      user['is_discoverable'] == true ? 'Yes' : 'No',
                    ),
                  ),
                  _AdminDetailRow(
                    icon: Icons.verified_user_outlined,
                    label: 'Profile verified',
                    value: context.tr(
                      user['is_verified'] == true ? 'Yes' : 'No',
                    ),
                  ),
                  _AdminDetailRow(
                    icon: Icons.verified_outlined,
                    label: 'Photo verified',
                    value: context.tr(
                      user['is_photo_verified'] == true ? 'Yes' : 'No',
                    ),
                  ),
                  _AdminDetailRow(
                    icon: Icons.task_alt_outlined,
                    label: 'Profile completed',
                    value: _adminDateTime(user['profile_completed_at']),
                  ),
                ],
              ),
              _AdminDetailsSection(
                title: 'Safety and account activity',
                rows: [
                  _AdminDetailRow(
                    icon: Icons.flag_outlined,
                    label: 'Open reports',
                    value: _adminDetailValue(user['open_reports']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.photo_library_outlined,
                    label: 'Profile photos',
                    value: _adminDetailValue(user['photo_count']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Subscription',
                    value: _adminDetailValue(user['subscription_tier']),
                  ),
                  _AdminDetailRow(
                    icon: Icons.schedule_outlined,
                    label: 'Deletion request',
                    value: _adminDetailValue(user['deletion_status']),
                  ),
                ],
              ),
              const _SectionTitle('Administrative actions'),
              if (!canManage)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Destructive actions are unavailable for your own account and for privileged accounts.',
                    ),
                  ),
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setStatus(user, 'active'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Activate'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _setStatus(user, 'suspended'),
                  icon: const Icon(Icons.person_off_outlined),
                  label: const Text('Suspend'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _setStatus(user, 'banned'),
                  icon: const Icon(Icons.block_outlined),
                  label: const Text('Ban'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _deleteAccount(user),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete account'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _verify(photo: false),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Verify profile'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _verify(photo: true),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Verify photo'),
              ),
              if (_busy) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    ],
  );
}

class _AdminDetailsSection extends StatelessWidget {
  const _AdminDetailsSection({required this.title, required this.rows});

  final String title;
  final List<_AdminDetailRow> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _SectionTitle(title),
      Card(
        child: Column(
          children: [
            for (var index = 0; index < rows.length; index++) ...[
              rows[index],
              if (index < rows.length - 1) const Divider(height: 1, indent: 56),
            ],
          ],
        ),
      ),
    ],
  );
}

class _AdminDetailRow extends StatelessWidget {
  const _AdminDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon),
    title: Text(label),
    subtitle: SelectableText(value),
  );
}

class _AdminTargetIdentity extends StatelessWidget {
  const _AdminTargetIdentity({required this.user});

  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _adminDetailValue(user['first_name']),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          SelectableText(_adminDetailValue(user['email'])),
          SelectableText(_adminDetailValue(user['phone'])),
          const SizedBox(height: 4),
          SelectableText(
            _adminDetailValue(user['id']),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
