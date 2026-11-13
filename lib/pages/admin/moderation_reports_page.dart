part of '../../app.dart';

class ModerationReportsScreen extends StatefulWidget {
  const ModerationReportsScreen({super.key, this.pendingOnly = false});

  final bool pendingOnly;

  @override
  State<ModerationReportsScreen> createState() =>
      _ModerationReportsScreenState();
}

class _ModerationReportsScreenState extends State<ModerationReportsScreen> {
  late Future<List<Map<String, dynamic>>> reports;
  late Future<List<Map<String, dynamic>>> moderatedProfiles;
  late Future<List<Map<String, dynamic>>> moderatedPhotos;
  final Set<String> _busyReports = {};
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    reports = MapLovRepository.instance.moderationReports(
      pendingOnly: widget.pendingOnly,
    );
    moderatedProfiles = MapLovRepository.instance.moderatedProfileQueue();
    moderatedPhotos = MapLovRepository.instance.moderatedPhotoQueue();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _reload());
  }

  Future<void> _runReportAction(
    String reportId,
    Future<void> Function() action,
  ) async {
    if (_busyReports.contains(reportId)) return;
    setState(() => _busyReports.add(reportId));
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('Action failed')}: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyReports.remove(reportId));
    }
  }

  Widget _reportTextAction({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    ),
  );

  bool _isChildSafetyReport(Map<String, dynamic> report) =>
      report['reason'] == 'Mineur présumé' ||
      report['reason'] == 'Exploitation sexuelle d’un enfant' ||
      report['reason'] == 'Suspected minor' ||
      report['reason'] == 'Child sexual exploitation';

  bool _canClose(Map<String, dynamic> report) =>
      !_isChildSafetyReport(report) || report['child_safety_action'] != null;

  Future<void> _recordChildSafetyAction(Map<String, dynamic> report) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('Child safety decision')),
        content: Text(
          context.tr(
            'Record a human decision. This form does not send a report to an authority.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, 'no_referral_required'),
            child: Text(context.tr('No external report required')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, 'reported_to_authority'),
            child: Text(context.tr('External report already sent')),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    final authority = TextEditingController();
    final reference = TextEditingController();
    final rationale = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            context.tr(
              action == 'reported_to_authority'
                  ? 'Record external report'
                  : 'Record review decision',
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: action == 'reported_to_authority'
                  ? [
                      TextField(
                        controller: authority,
                        maxLength: 120,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: context.tr('Authority or organization'),
                        ),
                      ),
                      TextField(
                        controller: reference,
                        maxLength: 200,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: context.tr('Receipt or case reference'),
                        ),
                      ),
                    ]
                  : [
                      TextField(
                        controller: rationale,
                        maxLines: 3,
                        maxLength: 1000,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: context.tr(
                            'Reason no external report is required',
                          ),
                        ),
                      ),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed:
                  (action == 'reported_to_authority'
                      ? authority.text.trim().isNotEmpty &&
                            reference.text.trim().isNotEmpty
                      : rationale.text.trim().isNotEmpty)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(context.tr('Save decision')),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await MapLovRepository.instance.recordChildSafetyAction(
          reportId: report['id'] as String,
          action: action,
          authority: authority.text.trim(),
          reference: reference.text.trim(),
          rationale: rationale.text.trim(),
        );
        _refresh();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.tr('Decision not saved')}: $error'),
            ),
          );
        }
      }
    }
    authority.dispose();
    reference.dispose();
    rationale.dispose();
  }

  Future<void> _moderate(String id, String status, {String? notes}) async {
    await MapLovRepository.instance.moderateReport(id, status, notes: notes);
    _refresh();
  }

  Future<String?> _decisionNotes(String title) async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: context.tr('Optional moderation notes'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return notes;
  }

  Future<void> _approvePhoto(String photoId) async {
    final notes = await _decisionNotes('Approve this photo?');
    if (notes == null) return;
    await MapLovRepository.instance.approveModeratedPhoto(
      photoId,
      notes: notes.isEmpty ? null : notes,
    );
    _refresh();
  }

  Future<void> _decideProfile(String profileId, String decision) async {
    final title = decision == 'approved'
        ? 'Approve and restore this profile?'
        : 'Confirm this profile suspension?';
    final notes = await _decisionNotes(title);
    if (notes == null) return;
    await MapLovRepository.instance.decideModeratedProfile(
      profileId,
      decision,
      notes: notes.isEmpty ? null : notes,
    );
    _refresh();
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete this photo?'),
        content: const Text(
          'The file and its public database record will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await MapLovRepository.instance.deleteModeratedPhoto(photoId);
    _refresh();
  }

  Future<void> _resolve(String id) async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve report'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: context.tr('Resolution notes'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null) return;
    await _moderate(id, 'resolved', notes: notes);
  }

  Future<void> _reviewReport(Map<String, dynamic> report) async {
    final id = report['id'] as String;
    if (report['status'] == 'open') await _moderate(id, 'under_review');
    if (!mounted) return;
    Map<String, dynamic>? evidence;
    try {
      evidence = await MapLovRepository.instance.moderationReportEvidence(id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load report evidence: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    final messages = List<Map<String, dynamic>>.from(
      (evidence?['messages'] as List? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final attachments = List<Map<String, dynamic>>.from(
      evidence?['attachments'] as List? ?? const [],
    );
    final participantNames = evidence?['participant_names'] as Map? ?? const {};
    final reporterId = evidence?['reporter_id']?.toString();
    final reportedUserId = evidence?['reported_user_id']?.toString();
    String authorLabel(Map<String, dynamic> message) {
      final senderId = message['sender_id']?.toString();
      final savedName = participantNames[senderId];
      final name = savedName is String && savedName.trim().isNotEmpty
          ? savedName.trim()
          : context.tr('Missing name');
      final role = senderId == reporterId
          ? context.tr('Reporting member').toLowerCase()
          : senderId == reportedUserId
          ? context.tr('Reported person').toLowerCase()
          : null;
      return role == null ? name : '$name ($role)';
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conversation evidence'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${context.tr('Reason')} : ${context.tr(report['reason'].toString())}',
                ),
                if (report['comment'] != null)
                  Text('${context.tr('Details')} : ${report['comment']}'),
                const SizedBox(height: 12),
                Text(
                  '${context.tr('Captured')} : ${_adminDateTime(evidence?['captured_at'])}',
                ),
                if (evidence?['media_finalized_at'] == null)
                  const Text(
                    'Attachment copying is incomplete. Review available text and retry evidence finalization.',
                  ),
                const Divider(),
                if (messages.isEmpty)
                  const Text(
                    'No conversation messages were available when this report was filed.',
                  ),
                for (final message in messages) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      message['body']?.toString().isNotEmpty == true
                          ? message['body'].toString()
                          : message['deleted_at'] != null
                          ? 'Message content was already erased before evidence retention.'
                          : '[${message['kind']}]',
                    ),
                    subtitle: Text(
                      '${context.tr('Author')} : ${authorLabel(message)} • '
                      '${_adminDateTime(message['created_at'])}'
                      '${message['reply_to_id'] == null ? '' : ' • ${context.tr('Reply to a message')}'}',
                    ),
                  ),
                  for (final attachment in attachments.where(
                    (item) => item['message_id'] == message['id'],
                  ))
                    TextButton.icon(
                      onPressed: () {
                        final url = attachment['url'] as String?;
                        if (url != null) unawaited(launchUrl(Uri.parse(url)));
                      },
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Open preserved attachment'),
                    ),
                  const Divider(),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _warnReportedUser(String reportId) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.tr('Warn this member?')),
          content: TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 2000,
            onChanged: (_) => setDialogState(() {}),
            decoration: InputDecoration(
              labelText: context.tr('Message to the member'),
              helperText: context.tr(
                'The member must read and confirm this message at their next sign-in.',
              ),
              helperMaxLines: 3,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(context.tr('Send warning')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (message == null || !mounted) return;
    try {
      await MapLovRepository.instance.warnReportedUser(reportId, message);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Warning sent to the member.'))),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('Warning was not sent')}: $error'),
        ),
      );
    }
  }

  Future<void> _banReportedUser(Map<String, dynamic> report) async {
    final notes = await _decisionNotes('Ban this member?');
    if (notes == null) return;
    await MapLovRepository.instance.setAccountStatus(
      report['target_id'] as String,
      'banned',
    );
    await _moderate(
      report['id'] as String,
      _canClose(report) ? 'resolved' : 'under_review',
      notes: notes.isEmpty ? 'Account banned after report review.' : notes,
    );
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: widget.pendingOnly ? 'Pending reports' : 'User reports',
    children: [
      Text(
        widget.pendingOnly
            ? 'Only reports that still require an administrative decision are shown.'
            : 'This page is protected by the PostgreSQL admin role and RLS policies.',
        style: const TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      if (!widget.pendingOnly) ...[
        const _SectionTitle('Profiles awaiting validation'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: moderatedProfiles,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text(
                'Unable to load profile moderation: ${snapshot.error}',
              );
            }
            final profiles = snapshot.data ?? const <Map<String, dynamic>>[];
            if (profiles.isEmpty) {
              return const Text('No profiles are awaiting validation.');
            }
            return Column(
              children: profiles.map((item) {
                final profile = item['profile'] as Map<String, dynamic>;
                final profileReports =
                    item['reports'] as List<Map<String, dynamic>>;
                final profileId = profile['id'] as String;
                final location = [profile['city'], profile['country_name']]
                    .whereType<String>()
                    .where((value) => value.isNotEmpty)
                    .join(', ');
                return Card(
                  key: Key('moderated_profile_$profileId'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_off_outlined),
                          ),
                          title: Text(
                            profile['first_name'] as String? ?? 'MapLov member',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            location.isEmpty
                                ? 'Frozen and removed from Discover'
                                : '$location • Frozen and removed from Discover',
                          ),
                        ),
                        Text(
                          '${item['report_count']} distinct reports',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        ...profileReports.map(
                          (report) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.flag_outlined,
                              color: AppColors.error,
                            ),
                            title: Text(report['reason'] as String),
                            subtitle: report['comment'] == null
                                ? null
                                : Text(report['comment'] as String),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    _decideProfile(profileId, 'suspended'),
                                icon: const Icon(Icons.lock_person_outlined),
                                label: const Text('Keep suspended'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _decideProfile(profileId, 'approved'),
                                icon: const Icon(Icons.verified_user_outlined),
                                label: const Text('Approve profile'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Photos awaiting review'),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: moderatedPhotos,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Unable to load photo moderation: ${snapshot.error}');
            }
            final photos = snapshot.data ?? const <Map<String, dynamic>>[];
            if (photos.isEmpty) {
              return const Text('No photos are awaiting review.');
            }
            return Column(
              children: photos.map((item) {
                final photo = item['photo'] as Map<String, dynamic>;
                final photoReports =
                    item['reports'] as List<Map<String, dynamic>>;
                final photoId = photo['id'] as String;
                return Card(
                  key: Key('moderated_photo_$photoId'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: SizedBox(
                            height: 260,
                            width: double.infinity,
                            child: mediaImage(
                              item['url'] as String,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${item['report_count']} distinct reports',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text('Owner: ${item['owner_id']}'),
                        ...photoReports.map(
                          (report) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.flag_outlined,
                              color: AppColors.error,
                            ),
                            title: Text(report['reason'] as String),
                            subtitle: report['comment'] == null
                                ? null
                                : Text(report['comment'] as String),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deletePhoto(photoId),
                                icon: const Icon(Icons.delete_forever_outlined),
                                label: const Text('Delete permanently'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => _approvePhoto(photoId),
                                icon: const Icon(Icons.verified_outlined),
                                label: const Text('Approve photo'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 18),
      ],
      _SectionTitle(
        widget.pendingOnly ? 'Reports awaiting action' : 'All reports',
      ),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: reports,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Access denied or unavailable: ${snapshot.error}');
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) return const Text('No reports to review.');
          return Column(
            children: items
                .map(
                  (report) => Card(
                    key: Key('moderation_report_${report['id']}'),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.flag, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.tr(report['reason'] as String),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(switch (report['status']) {
                                  'under_review' => 'Under review',
                                  'open' => 'Open',
                                  'resolved' => 'Resolved',
                                  'dismissed' => 'Dismissed',
                                  _ => report['status'].toString(),
                                }),
                              ),
                            ],
                          ),
                          if (_isChildSafetyReport(report)) ...[
                            Text(
                              context.tr('Priority child safety report'),
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              report['child_safety_action'] == null
                                  ? context.tr(
                                      'Human review decision required before closure.',
                                    )
                                  : context.tr(
                                      'Child safety decision recorded.',
                                    ),
                            ),
                            if (report['child_safety_action'] is Map)
                              Text(
                                (report['child_safety_action']
                                            as Map)['action'] ==
                                        'reported_to_authority'
                                    ? '${context.tr('External report already sent')}: '
                                          '${(report['child_safety_action'] as Map)['authority']} · '
                                          '${(report['child_safety_action'] as Map)['authority_reference']}'
                                    : '${context.tr('No external report required')}: '
                                          '${(report['child_safety_action'] as Map)['rationale']}',
                              ),
                            _reportTextAction(
                              icon: Icons.assignment_turned_in_outlined,
                              label: 'Record child safety decision',
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () => _recordChildSafetyAction(report),
                                    ),
                            ),
                          ],
                          _reportTextAction(
                            icon: Icons.task_alt,
                            label: 'Resolve with notes',
                            onPressed:
                                _canClose(report) &&
                                    !_busyReports.contains(report['id'])
                                ? () => _runReportAction(
                                    report['id'] as String,
                                    () => _resolve(report['id'] as String),
                                  )
                                : null,
                          ),
                          if (report['target_type'] != 'user' &&
                              report['target_type'] != 'photo')
                            _reportTextAction(
                              icon: Icons.delete_outline,
                              label: 'Remove reported content',
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () async {
                                        await MapLovRepository.instance
                                            .adminRemoveContent(
                                              report['target_type'] as String,
                                              report['target_id'] as String,
                                            );
                                        await _moderate(
                                          report['id'] as String,
                                          _canClose(report)
                                              ? 'resolved'
                                              : 'under_review',
                                          notes: 'Reported content removed.',
                                        );
                                      },
                                    ),
                            ),
                          if (report['target_type'] == 'photo')
                            const Text(
                              'Use the photo review queue above to approve or permanently remove this photo.',
                              style: TextStyle(color: AppColors.grayText),
                            ),
                          if (report['target_type'] == 'user')
                            _reportTextAction(
                              icon: Icons.person_off_outlined,
                              label: 'Suspend reported account',
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () async {
                                        await MapLovRepository.instance
                                            .setAccountStatus(
                                              report['target_id'] as String,
                                              'suspended',
                                            );
                                        await _moderate(
                                          report['id'] as String,
                                          _canClose(report)
                                              ? 'resolved'
                                              : 'under_review',
                                          notes:
                                              'Account suspended pending safety review.',
                                        );
                                      },
                                    ),
                            ),
                          if (report['target_type'] == 'user')
                            _reportTextAction(
                              icon: Icons.warning_amber_outlined,
                              label: 'Warn reported account',
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () => _warnReportedUser(
                                        report['id'] as String,
                                      ),
                                    ),
                            ),
                          if (report['target_type'] == 'user')
                            _reportTextAction(
                              icon: Icons.block_outlined,
                              label: 'Ban reported account',
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () => _banReportedUser(report),
                                    ),
                            ),
                          Text(
                            report['target_type'] == 'user'
                                ? '${context.tr('Reported account')} : ${report['reported_user_name'] ?? context.tr('Missing name')}'
                                : report['target_type'] == 'message'
                                ? '${context.tr('Message from')} : ${report['reported_user_name'] ?? context.tr('Missing name')}'
                                : '${context.tr('Reported content')} : ${report['target_type']}',
                          ),
                          Text(
                            '${context.tr('Reporting member')} : ${report['reporter_name'] ?? context.tr('Missing name')}',
                          ),
                          Text(
                            '${context.tr('Submitted')} : ${_adminDateTime(report['created_at'])}',
                          ),
                          if (report['comment'] != null)
                            Text(report['comment'] as String),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed:
                                  _canClose(report) &&
                                      !_busyReports.contains(report['id'])
                                  ? () => _runReportAction(
                                      report['id'] as String,
                                      () => _moderate(
                                        report['id'] as String,
                                        'dismissed',
                                      ),
                                    )
                                  : null,
                              child: const Text('Dismiss'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busyReports.contains(report['id'])
                                  ? null
                                  : () => _runReportAction(
                                      report['id'] as String,
                                      () => _reviewReport(report),
                                    ),
                              child: const Text('Review'),
                            ),
                          ),
                        ],
                      ),
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
