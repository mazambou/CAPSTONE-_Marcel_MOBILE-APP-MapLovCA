part of '../../app.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Legal & consent',
    children: const [
      ListTile(
        leading: Icon(Icons.description_outlined),
        title: Text('Terms of Use'),
        trailing: Icon(Icons.chevron_right),
      ),
      ListTile(
        leading: Icon(Icons.privacy_tip_outlined),
        title: Text('Privacy Policy'),
        trailing: Icon(Icons.chevron_right),
      ),
      ListTile(
        leading: Icon(Icons.cookie_outlined),
        title: Text('Data and cookie preferences'),
        trailing: Icon(Icons.chevron_right),
      ),
      ListTile(
        leading: Icon(Icons.location_on_outlined),
        title: Text('Location consent'),
        trailing: Icon(Icons.chevron_right),
      ),
      ListTile(
        leading: Icon(Icons.download_outlined),
        title: Text('Request a copy of my data'),
        trailing: Icon(Icons.chevron_right),
      ),
      Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'MapLov Canada is designed to comply with PIPEDA, Québec Law 25 and GDPR privacy principles.',
          style: TextStyle(color: AppColors.grayText),
        ),
      ),
    ],
  );
}
