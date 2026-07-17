part of '../../app.dart';

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({
    super.key,
    this.profile,
    this.targetType = 'user',
    this.targetId,
  });
  final UserProfile? profile;
  final String targetType;
  final String? targetId;

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  String reason = 'Fake profile';
  final comment = TextEditingController();
  bool blockAfterReporting = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target =
        widget.targetId ?? widget.profile?.id ?? demoProfileOrUnavailable.id;
    await MapLovRepository.instance.report(
      targetType: widget.targetType,
      targetId: target,
      reason: reason,
      comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
    );
    if (blockAfterReporting && widget.profile != null) {
      await MapLovRepository.instance.blockUser(widget.profile!.id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted for review.')),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Report ${widget.targetType}',
    children: [
      if (widget.profile != null)
        ListTile(
          leading: CircleAvatar(
            backgroundImage: profileImageProvider(widget.profile!),
          ),
          title: Text(
            widget.profile!.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: const Text('This report is confidential.'),
        )
      else
        const _UserSafetyCard(),
      const _SectionTitle('Why are you reporting this?'),
      RadioGroup<String>(
        groupValue: reason,
        onChanged: (selected) => setState(() => reason = selected ?? reason),
        child: Column(
          children:
              [
                    'Harassment',
                    'Fake profile',
                    'Inappropriate content',
                    'Spam or scam',
                    'Suspected minor',
                    'Child sexual exploitation',
                    'Non-consensual intimate content',
                    'Threat or immediate danger',
                    'Other',
                  ]
                  .map(
                    (value) =>
                        RadioListTile<String>(value: value, title: Text(value)),
                  )
                  .toList(),
        ),
      ),
      TextField(
        controller: comment,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Optional comment'),
      ),
      if (widget.profile != null)
        CheckboxListTile(
          value: blockAfterReporting,
          onChanged: (value) =>
              setState(() => blockAfterReporting = value ?? false),
          contentPadding: EdgeInsets.zero,
          title: const Text('Block this member after reporting'),
          subtitle: const Text(
            'You will no longer see each other or exchange messages.',
          ),
        ),
      const Card(
        color: AppColors.palePink,
        child: ListTile(
          leading: Icon(Icons.emergency_outlined, color: AppColors.error),
          title: Text('Immediate danger'),
          subtitle: Text(
            'Contact local emergency services. An in-app report is not an emergency service.',
          ),
        ),
      ),
      const SizedBox(height: 20),
      _PrimaryButton('Submit report', onPressed: _submit),
    ],
  );
}
