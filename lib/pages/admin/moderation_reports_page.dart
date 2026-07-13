part of '../../app.dart';

class ModerationReportsScreen extends StatefulWidget {
  const ModerationReportsScreen({super.key});
  @override
  State<ModerationReportsScreen> createState() =>
      _ModerationReportsScreenState();
}

class _ModerationReportsScreenState extends State<ModerationReportsScreen> {
  late Future<List<Map<String, dynamic>>> reports;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => reports = MapLovRepository.instance.moderationReports();

  Future<void> _moderate(String id, String status) async {
    await MapLovRepository.instance.moderateReport(id, status);
    if (mounted) setState(_reload);
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
