part of '../../app.dart';

class CompatibilityDetailsScreen extends StatelessWidget {
  const CompatibilityDetailsScreen({super.key, this.profile});

  final UserProfile? profile;

  Future<void> _openChat(BuildContext context, UserProfile selected) async {
    try {
      final id = await MapLovRepository.instance.startConversation(selected.id);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: id, profile: selected),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start conversation: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = profile ?? demoProfileOrUnavailable;
    final details = selected.compatibilityBreakdown;
    final score = selected.compatibilityScore;
    double value(String key, double fallback) =>
        ((details[key] as num?)?.toDouble() ?? fallback) / 100;
    return _AppPage(
      title: 'Compatibility details',
      children: [
        Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(value: score / 100, strokeWidth: 13),
                Text(
                  '$score%',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Highly compatible',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const _SectionTitle('Why you may connect'),
        _CompatibilityReason(
          Icons.favorite_outline,
          selected.relationshipGoal.isEmpty
              ? 'Your relationship preferences are compatible.'
              : 'Relationship goal: ${selected.relationshipGoal}.',
        ),
        _CompatibilityReason(
          Icons.translate,
          (details['shared_languages'] as int? ?? 0) > 0
              ? 'You share at least one language.'
              : 'You can discover a new language together.',
        ),
        _CompatibilityReason(
          Icons.location_on_outlined,
          'Location compatibility is based on ${selected.city}.',
        ),
        _CompatibilityReason(
          Icons.interests_outlined,
          '${details['shared_interests'] ?? 0} shared interests.',
        ),
        const _SectionTitle('Score breakdown'),
        _ScoreRow('Preferences', value('preferences', 80)),
        _ScoreRow('Interests', value('interests', 70)),
        _ScoreRow('Relationship goal', value('relationship', 75)),
        _ScoreRow('Languages', value('languages', 75)),
        _ScoreRow('Location', value('geography', 70)),
        const SizedBox(height: 22),
        _PrimaryButton(
          'Send a message',
          onPressed: () => _openChat(context, selected),
        ),
      ],
    );
  }
}

class _CompatibilityReason extends StatelessWidget {
  const _CompatibilityReason(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.coral),
      title: Text(text),
    ),
  );
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(width: 125, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: value)),
        const SizedBox(width: 10),
        Text('${(value * 100).round()}%'),
      ],
    ),
  );
}
