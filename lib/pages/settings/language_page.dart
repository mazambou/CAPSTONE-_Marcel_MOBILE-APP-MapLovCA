part of '../../app.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String selected;
  @override
  void initState() {
    super.initState();
    selected = LocaleService.instance.locale.languageCode;
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: MapLovLocalizations.of(context).text('language'),
    children: [
      const Text(
        'Choose the language used by MapLov.',
        style: TextStyle(color: AppColors.grayText),
      ),
      const SizedBox(height: 14),
      RadioGroup<String>(
        groupValue: selected,
        onChanged: (value) => setState(() => selected = value ?? 'en'),
        child: Column(
          children: const [
            RadioListTile<String>(
              value: 'en',
              title: Text('English'),
              secondary: Text('🇨🇦', style: TextStyle(fontSize: 24)),
            ),
            RadioListTile<String>(
              value: 'fr',
              title: Text('Français'),
              secondary: Text('⚜️', style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _PrimaryButton(
        MapLovLocalizations.of(context).text('apply_language'),
        onPressed: () async {
          await LocaleService.instance.setLanguage(selected);
          if (context.mounted) Navigator.pop(context);
        },
      ),
    ],
  );
}
