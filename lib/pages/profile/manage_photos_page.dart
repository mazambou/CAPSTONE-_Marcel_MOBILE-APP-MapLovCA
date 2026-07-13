part of '../../app.dart';

class ManagePhotosScreen extends StatelessWidget {
  const ManagePhotosScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Manage photos',
    children: [
      const Text(
        'Your first photo is your main profile photo. Drag photos to reorder them.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 18),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          ...mockProfiles.map(
            (profile) => ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(profile.imagePath, fit: BoxFit.cover),
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.close, size: 17),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.palePink,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.softPink),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: AppColors.coral),
                  SizedBox(height: 8),
                  Text('Add photo'),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _PrimaryButton(
        'Save photo order',
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
