part of '../../app.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Security',
    children: [
      const ListTile(
        leading: Icon(Icons.verified_user_outlined, color: AppColors.success),
        title: Text('Email verified'),
        subtitle: Text('jamie@example.com'),
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
        onPressed: () {},
        icon: const Icon(Icons.logout),
        label: const Text('Sign out of all other devices'),
      ),
    ],
  );
}
