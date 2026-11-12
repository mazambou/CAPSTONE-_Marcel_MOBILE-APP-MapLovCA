part of '../../app.dart';

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({
    super.key,
    this.profile,
    this.targetType = 'user',
    this.targetId,
    this.conversationId,
  });
  final UserProfile? profile;
  final String targetType;
  final String? targetId;
  final String? conversationId;

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  String reason = 'Harcèlement';
  final comment = TextEditingController();
  bool blockAfterReporting = false;
  bool submitting = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (submitting) return;
    setState(() => submitting = true);
    final target =
        widget.targetId ?? widget.profile?.id ?? demoProfileOrUnavailable.id;
    try {
      await MapLovRepository.instance.report(
        targetType: widget.targetType,
        targetId: target,
        reason: reason,
        comment: comment.text.trim().isEmpty ? null : comment.text.trim(),
        conversationId: widget.conversationId,
      );
      if (blockAfterReporting && widget.profile != null) {
        await MapLovRepository.instance.blockUser(widget.profile!.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signalement et preuves enregistrés.')),
        );
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        final message = error is ReportSubmissionException
            ? switch (error.code) {
                'report_rate_limited' => context.tr(
                  'Daily reporting limit reached. For an urgent child safety concern, contact child-safety@maplov.ca.',
                ),
                'conversation_unavailable' => context.tr(
                  'This conversation is no longer available for reporting.',
                ),
                'target_unavailable' => context.tr(
                  'This profile is no longer available for reporting.',
                ),
                'report_already_open' => context.tr(
                  'A report is already under review. Contact child-safety@maplov.ca if you have new information.',
                ),
                'evidence_unavailable' ||
                'attachment_copy_failed' ||
                'evidence_finalization_failed' => context.tr(
                  'The report evidence could not be saved. Please try again.',
                ),
                _ => context.tr(
                  'The report could not be saved. Please try again or contact child-safety@maplov.ca for a child safety concern.',
                ),
              }
            : context.tr(
                'The report could not be saved. Please try again or contact child-safety@maplov.ca for a child safety concern.',
              );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AppPage(
    title: widget.targetType == 'user'
        ? 'Signaler l’utilisateur'
        : 'Signaler le contenu',
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
      const _SectionTitle('Pourquoi effectuez-vous ce signalement ?'),
      RadioGroup<String>(
        groupValue: reason,
        onChanged: (selected) => setState(() => reason = selected ?? reason),
        child: Column(
          children:
              [
                    'Harcèlement',
                    'Faux profil',
                    'Contenu inapproprié',
                    'Spam',
                    'Mineur présumé',
                    'Exploitation sexuelle d’un enfant',
                    'Contenu illégitime',
                    'Menace ou danger immédiat',
                    'Autre',
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
        decoration: InputDecoration(labelText: context.tr('Optional details')),
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
      _PrimaryButton('Envoyer le signalement', onPressed: _submit),
    ],
  );
}
