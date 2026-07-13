part of '../../app.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});
  @override
  Widget build(BuildContext context) => _MainPage(
    index: 0,
    title: 'Discover',
    actions: [
      IconButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.filters),
        icon: const Icon(Icons.tune),
      ),
    ],
    children: mockProfiles
        .map(
          (profile) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _DiscoverCard(profile),
          ),
        )
        .toList(),
  );
}
