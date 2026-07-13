part of '../../../app.dart';

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimary,
  });
  final String title;
  final String subtitle;
  final String image;
  final List<_Field> fields;
  final String primaryLabel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _ResponsiveBody(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              SizedBox(
                height: 180,
                child: Image.asset(image, fit: BoxFit.contain),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: AppColors.grayText)),
              const SizedBox(height: 24),
              ...fields.expand((field) => [field, const SizedBox(height: 12)]),
              const SizedBox(height: 18),
              _PrimaryButton(primaryLabel, onPressed: onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.icon, {this.secret = false});
  final String label;
  final IconData icon;
  final bool secret;
  @override
  Widget build(BuildContext context) => TextField(
    obscureText: secret,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
  );
}
