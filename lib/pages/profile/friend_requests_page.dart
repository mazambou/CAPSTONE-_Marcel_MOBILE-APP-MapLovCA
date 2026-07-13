part of '../../app.dart';

class FriendRequestsScreen extends StatelessWidget {
  const FriendRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Friend requests'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Received'),
            Tab(text: 'Sent'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          ListView(
            children: mockProfiles
                .map(
                  (p) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage(p.imagePath),
                    ),
                    title: Text(p.name),
                    subtitle: const Text('Wants to connect'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.check,
                            color: AppColors.success,
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          ListView(
            children: mockProfiles
                .take(2)
                .map(
                  (p) => ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage(p.imagePath),
                    ),
                    title: Text(p.name),
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('Cancel'),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
  );
}
