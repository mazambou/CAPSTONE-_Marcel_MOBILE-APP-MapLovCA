part of '../../app.dart';

/// Compatibility wrapper for older links. Discovery now has one canonical
/// implementation in [HomeScreen].
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
