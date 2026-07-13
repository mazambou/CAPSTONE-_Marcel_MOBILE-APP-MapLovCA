part of '../../app.dart';

class AccessRequestsScreen extends StatefulWidget {
  const AccessRequestsScreen({super.key});
  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen> {
  late Future<List<GardenRequestItem>> requests;
  final Map<String, int?> durations = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => requests = MapLovRepository.instance.gardenRequests();

  Future<void> _respond(GardenRequestItem item, bool allow) async {
    await MapLovRepository.instance.respondGardenRequest(
      item.id,
      allow: allow,
      seconds: durations[item.id] ?? item.requestedSeconds,
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Garden access requests',
    children: [
      const Text(
        'You decide who can view your private albums and for how long.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<GardenRequestItem>>(
        future: requests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <GardenRequestItem>[];
          if (items.isEmpty) return const Text('No access request is waiting.');
          return Column(
            children: items
                .map(
                  (item) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: profileImageProvider(
                                item.requester,
                              ),
                            ),
                            title: Text(
                              item.requester.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: const Text(
                              'Requested access to a private album',
                            ),
                          ),
                          DropdownButtonFormField<int?>(
                            initialValue: item.requestedSeconds,
                            decoration: const InputDecoration(
                              labelText: 'Access duration',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 300,
                                child: Text('5 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 600,
                                child: Text('10 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 1200,
                                child: Text('20 minutes'),
                              ),
                              DropdownMenuItem(
                                value: 3600,
                                child: Text('1 hour'),
                              ),
                              DropdownMenuItem(
                                value: null,
                                child: Text('Permanent'),
                              ),
                            ],
                            onChanged: (value) => durations[item.id] = value,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _respond(item, false),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _respond(item, true),
                                  child: const Text('Allow'),
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
