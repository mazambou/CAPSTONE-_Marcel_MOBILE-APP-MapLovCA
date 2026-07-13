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

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final target =
        widget.targetId ?? widget.profile?.id ?? mockProfiles.first.id;
    await MapLovRepository.instance.report(
      targetType: widget.targetType,
      targetId: target,
      reason: reason,
      comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
    );
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
      const SizedBox(height: 20),
      _PrimaryButton('Submit report', onPressed: _submit),
    ],
  );
}
