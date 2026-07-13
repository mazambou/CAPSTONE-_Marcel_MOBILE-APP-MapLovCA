part of '../../app.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  bool confirmed = false;

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Age confirmation',
    children: [
      const Icon(Icons.cake_outlined, size: 82, color: AppColors.coral),
      const SizedBox(height: 18),
      Text(
        'MapLov is for adults only',
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      const Text(
        'You must be at least 18 years old to create an account and use MapLov Canada.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 26),
      const _Field('Date of birth', Icons.calendar_month_outlined),
      CheckboxListTile(
        value: confirmed,
        onChanged: (value) => setState(() => confirmed = value ?? false),
        activeColor: AppColors.coral,
        contentPadding: EdgeInsets.zero,
        title: const Text('I confirm that I am 18 years of age or older.'),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: confirmed
              ? () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.register)
              : null,
          child: const Text('Continue'),
        ),
      ),
    ],
  );
}
