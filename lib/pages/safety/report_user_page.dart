part of '../../app.dart';

class ReportUserScreen extends StatelessWidget {
  const ReportUserScreen({super.key});
  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Report user',
    children: [
      const _UserSafetyCard(),
      const _SectionTitle('Why are you reporting this user?'),
      ...[
        'Harassment',
        'Fake profile',
        'Inappropriate content',
        'Spam or scam',
        'Other',
      ].map(
        (reason) => ListTile(
          onTap: () {},
          leading: Icon(
            reason == 'Fake profile'
                ? Icons.radio_button_checked
                : Icons.radio_button_off,
            color: AppColors.coral,
          ),
          title: Text(reason),
        ),
      ),
      const TextField(
        maxLines: 4,
        decoration: InputDecoration(labelText: 'Optional comment'),
      ),
      const SizedBox(height: 20),
      _PrimaryButton('Submit report', onPressed: () => Navigator.pop(context)),
    ],
  );
}
