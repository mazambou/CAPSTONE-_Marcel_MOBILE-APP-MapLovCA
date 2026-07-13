part of '../../app.dart';

class CompatibilityDetailsScreen extends StatelessWidget {
  const CompatibilityDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) => _AppPage(
    title: 'Compatibility details',
    children: [
      const Center(
        child: SizedBox(
          width: 150,
          height: 150,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(value: 0.94, strokeWidth: 13),
              Text(
                '94%',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
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
      const _CompatibilityReason(
        Icons.favorite_outline,
        'You are both looking for a long-term relationship.',
      ),
      const _CompatibilityReason(
        Icons.translate,
        'You both speak English and French.',
      ),
      const _CompatibilityReason(
        Icons.location_on_outlined,
        'You live in the same city.',
      ),
      const _CompatibilityReason(
        Icons.interests_outlined,
        'You share travel, music and hiking interests.',
      ),
      const _SectionTitle('Score breakdown'),
      const _ScoreRow('Preferences', 0.96),
      const _ScoreRow('Interests', 0.90),
      const _ScoreRow('Relationship goal', 1),
      const _ScoreRow('Languages', 1),
      const _ScoreRow('Location', 0.86),
      const SizedBox(height: 22),
      _PrimaryButton(
        'Send a message',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
      ),
    ],
  );
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
