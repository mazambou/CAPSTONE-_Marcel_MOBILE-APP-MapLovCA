part of '../../app.dart';

class AdminAuditScreen extends StatelessWidget {
  const AdminAuditScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Moderator audit log',
    children: [
      FutureBuilder<List<Map<String, dynamic>>>(
        future: MapLovRepository.instance.adminAuditLog(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text('Access denied or unavailable: ${snapshot.error}');
          }
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          if (items.isEmpty) {
            return const Text('No moderation action has been recorded.');
          }
          return Column(
            children: items
                .map(
                  (action) => ListTile(
                    leading: const Icon(Icons.history, color: AppColors.coral),
                    title: Text(action['action'] as String),
                    subtitle: Text(
                      '${action['target_type']} • ${action['target_id'] ?? 'n/a'}',
                    ),
                    trailing: Text(
                      (action['created_at'] as String).split('T').first,
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
