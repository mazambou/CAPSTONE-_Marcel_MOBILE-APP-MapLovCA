part of '../../app.dart';

class RegistrationGateData {
  const RegistrationGateData({
    required this.dateOfBirth,
    required this.acceptedDocuments,
    required this.acceptedAt,
  });

  final DateTime dateOfBirth;
  final Map<String, String> acceptedDocuments;
  final DateTime acceptedAt;
}

const _legalDocumentVersions = <String, String>{
  'terms_of_use': '2026-07-16',
  'privacy_policy': '2026-07-16',
  'community_guidelines': '2026-07-16',
  'adult_eligibility': '2026-07-16',
  'content_and_safety_rules': '2026-07-16',
};

class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({super.key});

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  final Set<String> acceptedDocuments = {};
  DateTime? dateOfBirth;

  bool get _allAccepted =>
      acceptedDocuments.length == _legalDocumentVersions.length;

  void _openLegalDocument(String key) {
    final (title, sections) = switch (key) {
      'terms_of_use' => ('Terms of Use', _termsSections),
      'privacy_policy' => ('Privacy Policy', _privacySections),
      'community_guidelines' => ('Community Guidelines', _communitySections),
      'adult_eligibility' => ('Adult eligibility', _childSafetySections),
      _ => ('Content, reporting and safety rules', _communitySections),
    };
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LegalDocumentScreen(title: title, sections: sections),
      ),
    );
  }

  Widget _acceptanceTile(String key, String prefix, String linkLabel) {
    final checked = acceptedDocuments.contains(key);
    return CheckboxListTile(
      value: checked,
      onChanged: (value) => setState(() {
        if (value ?? false) {
          acceptedDocuments.add(key);
        } else {
          acceptedDocuments.remove(key);
        }
      }),
      activeColor: AppColors.coral,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(prefix),
          TextButton(
            onPressed: () => _openLegalDocument(key),
            child: Text(linkLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final latestAllowed = DateTime(now.year - 18, now.month, now.day);
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (_) => _BirthDatePickerDialog(
        initialDate: dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
        firstDate: DateTime(1900),
        lastDate: latestAllowed,
      ),
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
      const _SectionTitle('Agreements and MapLov rules'),
      _acceptanceTile(
        'terms_of_use',
        'I have read and accept the ',
        'Terms of Use',
      ),
      _acceptanceTile(
        'privacy_policy',
        'I have read and accept the ',
        'Privacy Policy',
      ),
      _acceptanceTile(
        'community_guidelines',
        'I have read and accept the ',
        'Community Guidelines',
      ),
      _acceptanceTile(
        'adult_eligibility',
        'I confirm that I am at least 18 and accept the ',
        'adult eligibility rules',
      ),
      _acceptanceTile(
        'content_and_safety_rules',
        'I accept the ',
        'content, photo, reporting and safety rules',
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _allAccepted && dateOfBirth != null
              ? () => Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.register,
                  arguments: RegistrationGateData(
                    dateOfBirth: dateOfBirth!,
                    acceptedDocuments: Map.unmodifiable(
                      acceptedDocuments.fold(
                        <String, String>{},
                        (result, key) =>
                            result..[key] = _legalDocumentVersions[key]!,
                      ),
                    ),
                    acceptedAt: DateTime.now().toUtc(),
                  ),
                )
              : null,
          child: const Text('Continue'),
        ),
      ),
    ],
  );
}

class _BirthDatePickerDialog extends StatefulWidget {
  const _BirthDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_BirthDatePickerDialog> createState() => _BirthDatePickerDialogState();
}

class _BirthDatePickerDialogState extends State<_BirthDatePickerDialog> {
  late DateTime selected = widget.initialDate;

  DateTime _inYear(int year) {
    final days = DateUtils.getDaysInMonth(year, selected.month);
    final day = selected.day > days ? days : selected.day;
    final candidate = DateTime(year, selected.month, day);
    if (candidate.isBefore(widget.firstDate)) return widget.firstDate;
    if (candidate.isAfter(widget.lastDate)) return widget.lastDate;
    return candidate;
  }

  void _changeYear(int offset) {
    final year = selected.year + offset;
    if (year < widget.firstDate.year || year > widget.lastDate.year) return;
    setState(() => selected = _inYear(year));
  }

  Future<void> _selectYear() async {
    final year = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView.builder(
          key: const Key('birth_year_list'),
          itemCount: widget.lastDate.year - widget.firstDate.year + 1,
          itemBuilder: (context, index) {
            final value = widget.lastDate.year - index;
            return ListTile(
              selected: value == selected.year,
              title: Text('$value', textAlign: TextAlign.center),
              onTap: () => Navigator.pop(context, value),
            );
          },
        ),
      ),
    );
    if (year != null) setState(() => selected = _inYear(year));
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select your date of birth',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const Key('previous_birth_year'),
                  tooltip: 'Previous year',
                  onPressed: selected.year > widget.firstDate.year
                      ? () => _changeYear(-1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                TextButton.icon(
                  key: const Key('select_birth_year'),
                  onPressed: _selectYear,
                  label: Text(
                    '${selected.year}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  icon: const Icon(Icons.arrow_drop_down),
                  iconAlignment: IconAlignment.end,
                ),
                IconButton(
                  key: const Key('next_birth_year'),
                  tooltip: 'Next year',
                  onPressed: selected.year < widget.lastDate.year
                      ? () => _changeYear(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            CalendarDatePicker(
              key: ValueKey(
                'birth_calendar_${selected.year}_${selected.month}',
              ),
              initialDate: selected,
              firstDate: widget.firstDate,
              lastDate: widget.lastDate,
              onDateChanged: (value) => setState(() => selected = value),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
