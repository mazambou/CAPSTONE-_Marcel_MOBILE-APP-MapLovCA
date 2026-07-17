part of '../../app.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _codeController = TextEditingController();
  bool _sending = true;
  bool _verifying = false;
  bool _deferring = false;
  String? _message;
  bool _messageIsError = false;
  String? _phone;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final phone = await AuthService.instance.phoneNumberForVerification();
    if (!mounted) return;
    setState(() => _phone = phone);
    await _sendCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    setState(() {
      _sending = true;
      _message = null;
    });
    if (_phone == null || _phone!.isEmpty) {
      setState(() {
        _sending = false;
        _message =
            'The phone number could not be recovered. Return to the previous steps or continue with the temporary testing option.';
        _messageIsError = true;
      });
      return;
    }
    try {
      if (resend) {
        await AuthService.instance.resendPhoneVerification();
      } else {
        await AuthService.instance.sendPhoneVerification();
      }
      if (mounted) {
        setState(() {
          _message =
              'A 6-digit verification code was sent to ${_phone ?? 'this number'}.';
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _backToPreferences() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.preferences);
    }
  }

  Future<void> _continueForTesting() async {
    setState(() {
      _deferring = true;
      _message = null;
    });
    try {
      await AuthService.instance.deferPhoneVerificationForTesting();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _deferring = false);
    }
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _message = 'Enter the 6-digit code sent by SMS.';
        _messageIsError = true;
      });
      return;
    }
    setState(() {
      _verifying = true;
      _message = null;
    });
    try {
      await AuthService.instance.verifyPhone(code);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _phone ?? 'Phone number unavailable';
    return _AppPage(
      title: 'Verify your phone number',
      children: [
        const Icon(Icons.sms_outlined, size: 88, color: AppColors.coral),
        const SizedBox(height: 20),
        Text(
          'Confirm this phone number',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          key: const Key('phone_number_being_verified'),
          color: AppColors.palePink,
          child: ListTile(
            leading: const Icon(Icons.phone_android, color: AppColors.coral),
            title: const Text('Phone number being verified'),
            subtitle: SelectableText(
              phone,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.darkText,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Phone verification protects accounts and helps keep MapLov authentic.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grayText),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const Key('phone_verification_code'),
          controller: _codeController,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _verify(),
          decoration: const InputDecoration(
            labelText: '6-digit code',
            prefixIcon: Icon(Icons.password_outlined),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _messageIsError ? AppColors.error : AppColors.grayText,
            ),
          ),
        ],
        const SizedBox(height: 18),
        _PrimaryButton(
          _verifying ? 'Verifying…' : 'Verify phone number',
          onPressed: _verifying ? () {} : _verify,
        ),
        TextButton(
          onPressed: _sending ? null : () => _sendCode(resend: true),
          child: Text(_sending ? 'Sending…' : 'Resend code'),
        ),
        TextButton.icon(
          key: const Key('phone_back_to_preferences'),
          onPressed: _sending || _verifying || _deferring
              ? null
              : _backToPreferences,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to dating preferences'),
        ),
        if (AppConfig.allowTestingBypass) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Temporary testing option: the phone will remain unverified.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayText, fontSize: 12),
          ),
          TextButton(
            key: const Key('defer_phone_verification'),
            onPressed: _sending || _verifying || _deferring
                ? null
                : _continueForTesting,
            child: Text(
              _deferring
                  ? 'Continuing…'
                  : 'Continue without verification (testing)',
            ),
          ),
        ],
      ],
    );
  }
}
