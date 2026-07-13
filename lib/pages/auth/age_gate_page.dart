part of '../../app.dart';

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  bool confirmed = false;
  DateTime? dateOfBirth;

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final latestAllowed = DateTime(now.year - 18, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: latestAllowed,
      helpText: 'Select your date of birth',
    );
    if (selected != null && mounted) setState(() => dateOfBirth = selected);
  }

  String get _formattedDate {
    final value = dateOfBirth;
    if (value == null) return 'Select your date of birth';
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

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
      Card(
        child: ListTile(
          onTap: _selectDateOfBirth,
          leading: const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.coral,
          ),
          title: const Text('Date of birth'),
          subtitle: Text(_formattedDate),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
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
          onPressed: confirmed && dateOfBirth != null
              ? () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.register,
                  arguments: dateOfBirth,
                )
              : null,
          child: const Text('Continue'),
        ),
      ),
    ],
  );
}
