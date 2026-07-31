part of '../../app.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Security',
    children: [
      ListTile(
        leading: Icon(
          AuthService.instance.isEmailVerified
              ? Icons.verified_user_outlined
              : Icons.mark_email_unread_outlined,
          color: AuthService.instance.isEmailVerified
              ? AppColors.success
              : AppColors.coral,
        ),
        title: Text(
          AuthService.instance.isEmailVerified
              ? 'Email verified'
              : 'Email verification pending',
        ),
        subtitle: Text(
          AuthService.instance.currentEmail ?? 'No email address available',
        ),
      ),
      ListTile(
        leading: const Icon(Icons.alternate_email_outlined),
        title: const Text('Change email address'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.changeEmail),
      ),
      ListTile(
        leading: const Icon(Icons.password_outlined),
        title: const Text('Change password'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.pushNamed(context, AppRoutes.resetPassword),
      ),
      const ListTile(
        leading: Icon(Icons.devices_outlined),
        title: Text('Active sessions'),
        subtitle: Text('1 signed-in device'),
        trailing: Icon(Icons.chevron_right),
      ),
      const ListTile(
        leading: Icon(Icons.login_outlined),
        title: Text('Recent login activity'),
        subtitle: Text('Toronto, Canada • Today'),
      ),
      const _SectionTitle('Account protection'),
      OutlinedButton.icon(
        onPressed: () async {
          try {
            await AuthService.instance.signOutOtherDevices();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Other sessions were signed out.')),
            );
          } catch (error) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AuthService.instance.messageFor(error))),
            );
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign out of all other devices'),
      ),
    ],
  );
}
