part of '../../app.dart';

class ModerationReportsScreen extends StatefulWidget {
  const ModerationReportsScreen({super.key});
  @override
  State<ModerationReportsScreen> createState() =>
      _ModerationReportsScreenState();
}

class _ModerationReportsScreenState extends State<ModerationReportsScreen> {
  late Future<List<Map<String, dynamic>>> reports;
  late Future<List<Map<String, dynamic>>> moderatedPhotos;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    reports = MapLovRepository.instance.moderationReports();
    moderatedPhotos = MapLovRepository.instance.moderatedPhotoQueue();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() => _reload());
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
          decoration: const InputDecoration(
            labelText: 'Optional moderation notes',
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
          decoration: const InputDecoration(labelText: 'Resolution notes'),
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

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'User reports',
    children: [
      const Text(
        'This page is protected by the PostgreSQL admin role and RLS policies.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
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
      const _SectionTitle('All reports'),
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
                                  report['reason'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Chip(label: Text(report['status'] as String)),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _resolve(report['id'] as String),
                              icon: const Icon(Icons.task_alt),
                              label: const Text('Resolve with notes'),
                            ),
                          ),
                          if (report['target_type'] != 'user' &&
                              report['target_type'] != 'photo')
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await MapLovRepository.instance
                                      .adminRemoveContent(
                                        report['target_type'] as String,
                                        report['target_id'] as String,
                                      );
                                  await _moderate(
                                    report['id'] as String,
                                    'resolved',
                                    notes: 'Reported content removed.',
                                  );
                                },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove reported content'),
                              ),
                            ),
                          if (report['target_type'] == 'photo')
                            const Text(
                              'Use the photo review queue above to approve or permanently remove this photo.',
                              style: TextStyle(color: AppColors.grayText),
                            ),
                          if (report['target_type'] == 'user')
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await MapLovRepository.instance
                                      .setAccountStatus(
                                        report['target_id'] as String,
                                        'suspended',
                                      );
                                  await _moderate(
                                    report['id'] as String,
                                    'resolved',
                                    notes:
                                        'Account suspended pending safety review.',
                                  );
                                },
                                icon: const Icon(Icons.person_off_outlined),
                                label: const Text('Suspend reported account'),
                              ),
                            ),
                          Text(
                            'Target: ${report['target_type']} • ${report['target_id']}',
                          ),
                          if (report['comment'] != null)
                            Text(report['comment'] as String),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _moderate(
                                    report['id'] as String,
                                    'dismissed',
                                  ),
                                  child: const Text('Dismiss'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _moderate(
                                    report['id'] as String,
                                    'under_review',
                                  ),
                                  child: const Text('Review'),
                                ),
                              ),
                            ],
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
