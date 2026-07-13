part of '../../app.dart';

class GardenViewerScreen extends StatelessWidget {
  const GardenViewerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF17131B),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleSpacing: 0,
      title: const Text(
        'Sophie’s Secret Garden',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 17),
      ),
    ),
    body: SafeArea(
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: AppColors.softPink),
                SizedBox(width: 8),
                Text(
                  'Access expires in 09:42',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              children: mockProfiles
                  .map(
                    (profile) => InteractiveViewer(
                      child: Image.asset(
                        profile.imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Private content cannot be shared or downloaded.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}
