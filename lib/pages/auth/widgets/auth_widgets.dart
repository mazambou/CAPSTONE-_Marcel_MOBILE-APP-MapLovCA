part of '../../../app.dart';

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.image,
    required this.fields,
    required this.primaryLabel,
    required this.onPrimary,
    this.errorText,
    this.isLoading = false,
  });
  final String title;
  final String subtitle;
  final String image;
  final List<Widget> fields;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? errorText;
  final bool isLoading;

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
              if (errorText != null) ...[
                Text(
                  errorText!,
                  style: const TextStyle(color: AppColors.error),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isLoading ? null : onPrimary,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          primaryLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field(
    this.label,
    this.icon, {
    this.secret = false,
    this.controller,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
    this.autofillHints,
  });
  final String label;
  final IconData icon;
  final bool secret;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final Iterable<String>? autofillHints;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  late bool _obscured = widget.secret;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _obscured,
    keyboardType: widget.keyboardType,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    enabled: widget.enabled,
    autofillHints: widget.autofillHints,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: Icon(widget.icon),
      suffixIcon: widget.secret
          ? IconButton(
              key: Key(
                'toggle_${widget.label.toLowerCase().replaceAll(' ', '_')}',
              ),
              tooltip: _obscured ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => _obscured = !_obscured),
              icon: Icon(
                _obscured
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            )
          : null,
    ),
  );
}
