part of '../../app.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Edit Profile', Icons.edit_outlined, AppRoutes.editProfile),
      ('Privacy', Icons.visibility_outlined, AppRoutes.privacy),
      (
        'Photo Display',
        Icons.photo_library_outlined,
        AppRoutes.photoDisplaySettings,
      ),
      ('Security', Icons.security, AppRoutes.security),
      (
        'Notifications',
        Icons.notifications_outlined,
        AppRoutes.notificationSettings,
      ),
      ('Language', Icons.language, AppRoutes.language),
      (
        'Subscription',
        Icons.workspace_premium_outlined,
        AppRoutes.subscriptionManagement,
      ),
      ('Blocked Users', Icons.block, AppRoutes.blockedUsers),
      ('Help Center', Icons.help_outline, AppRoutes.helpCenter),
      ('Legal & Consent', Icons.description_outlined, AppRoutes.legal),
    ];
    return _AppPage(
      title: 'Settings',
      children: [
        ...items.map(
          (item) => Card(
            child: ListTile(
              leading: Icon(item.$2, color: AppColors.coral),
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, item.$3),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log Out'),
          onTap: () async {
            try {
              await AuthService.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (_) => false,
              );
            } catch (error) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AuthService.instance.messageFor(error))),
              );
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.error),
          title: const Text(
            'Delete Account',
            style: TextStyle(color: AppColors.error),
          ),
          onTap: () => Navigator.pushNamed(context, AppRoutes.deleteAccount),
        ),
      ],
    );
  }
}
