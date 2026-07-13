part of '../../app.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String selected = 'English';

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Language',
    children: [
      const Text(
        'Choose the language used by MapLov.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) => setState(() => selected = value ?? 'English'),
        child: Column(
          children: ['English', 'Français']
              .map(
                (language) => RadioListTile<String>(
                  value: language,
                  title: Text(language),
                  secondary: Text(
                    language == 'English' ? '🇨🇦' : '⚜️',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              )
              .toList(),
        ),
      ),
      const SizedBox(height: 18),
      _PrimaryButton('Apply language', onPressed: () => Navigator.pop(context)),
    ],
  );
}
