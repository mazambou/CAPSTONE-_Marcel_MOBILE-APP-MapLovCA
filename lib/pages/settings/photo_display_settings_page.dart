part of '../../app.dart';

class PhotoDisplaySettingsScreen extends StatefulWidget {
  const PhotoDisplaySettingsScreen({super.key});

  @override
  State<PhotoDisplaySettingsScreen> createState() =>
      _PhotoDisplaySettingsScreenState();
}

class _PhotoDisplaySettingsScreenState
    extends State<PhotoDisplaySettingsScreen> {
  late PhotoDisplayStyle selectedStyle;

  @override
  void initState() {
    super.initState();
    selectedStyle = currentUserPhotoDisplayStyle;
  }

  void _savePreference() {
    currentUserPhotoDisplayStyle = selectedStyle;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Photo display',
    children: [
      const Text(
        'Choose how other MapLov members will see your profile photos. You can change this preference at any time.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 18),
      _PhotoDisplayOption(
        key: const Key('photo_display_profile_details'),
        title: 'Profile details',
        subtitle:
            'Shows your photo with your relationship goal, location, age, height and biography.',
        icon: Icons.badge_outlined,
        selected: selectedStyle == PhotoDisplayStyle.profileDetails,
        features: const [
          'Detailed profile information',
          'Photo navigation and counter',
          'Pass, Like and Super Like actions',
        ],
        onTap: () =>
            setState(() => selectedStyle = PhotoDisplayStyle.profileDetails),
      ),
      const SizedBox(height: 14),
      _PhotoDisplayOption(
        key: const Key('photo_display_social'),
        title: 'Social interactions',
        subtitle:
            'Uses an immersive photo layout where visitors can like, comment or send a Super Like.',
        icon: Icons.favorite_outline,
        selected: selectedStyle == PhotoDisplayStyle.social,
        features: const [
          'Like profile photos',
          'Read and add comments',
          'Super Like without a share action',
        ],
        onTap: () => setState(() => selectedStyle = PhotoDisplayStyle.social),
      ),
      const SizedBox(height: 22),
      _PrimaryButton('Save photo display', onPressed: _savePreference),
      const SizedBox(height: 10),
      const Text(
        'This setting controls only the presentation of your profile photos. Your privacy and visibility settings remain unchanged.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText, fontSize: 12),
      ),
    ],
  );
}

class _PhotoDisplayOption extends StatelessWidget {
  const _PhotoDisplayOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.features,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final List<String> features;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.palePink : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.coral : AppColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: selected
                        ? AppColors.coral
                        : AppColors.lightGray,
                    foregroundColor: selected
                        ? AppColors.white
                        : AppColors.darkText,
                    child: Icon(icon),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: selected ? AppColors.coral : AppColors.grayText,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(subtitle, style: const TextStyle(color: AppColors.grayText)),
              const SizedBox(height: 12),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 17,
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(feature)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
