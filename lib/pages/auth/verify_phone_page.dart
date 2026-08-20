part of '../../app.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  final _codeController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _sending = true;
  bool _verifying = false;
  bool _savingPhone = false;
  bool _codeSent = false;
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
    setState(() {
      _phone = phone;
      _sending = false;
      if (phone == null || phone.isEmpty) {
        _message = AuthService.instance.isPhoneVerificationExempt
            ? 'A phone number is required. No SMS verification is required in your country.'
            : 'Enter your phone number in international format to continue.';
        _messageIsError = !AuthService.instance.isPhoneVerificationExempt;
      } else if (AuthService.instance.isPhoneVerificationExempt) {
        _message = 'No SMS verification is required in your country.';
        _messageIsError = false;
      }
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _savePhoneAndSend() async {
    setState(() {
      _savingPhone = true;
      _message = null;
    });
    try {
      await AuthService.instance.setPhoneNumberForVerification(
        _phoneController.text,
      );
      final phone = await AuthService.instance.phoneNumberForVerification();
      if (!mounted) return;
      setState(() => _phone = phone);
      if (AuthService.instance.isPhoneVerificationExempt) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
        return;
      }
      await _sendCode();
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = AuthService.instance.messageFor(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _savingPhone = false);
    }
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
            'Enter your phone number in international format to continue.';
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
          _codeSent = true;
          _message =
              'A verification code was sent to ${_phone ?? 'this number'}.';
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

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _message = 'Enter the verification code sent by SMS.';
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
    final skipsSms = AuthService.instance.isPhoneVerificationExempt;
    return _AppPage(
      title: skipsSms ? 'Add your phone number' : 'Verify your phone number',
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
          'A phone number is required for every MapLov account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.grayText),
        ),
        if (skipsSms) ...[
          const SizedBox(height: 8),
          const Text(
            'SMS verification is not required in your country. Your selfie remains the identity verification method.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grayText),
          ),
        ],
        const SizedBox(height: 24),
        if (_phone == null || _phone!.isEmpty) ...[
          TextField(
            key: const Key('phone_number_for_verification'),
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumber],
            onSubmitted: (_) => _savePhoneAndSend(),
            decoration: InputDecoration(
              labelText: context.tr('Phone number (+country code)'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            _savingPhone
                ? 'Saving…'
                : skipsSms
                ? 'Save phone number'
                : 'Save number and send code',
            onPressed: _savingPhone ? () {} : _savePhoneAndSend,
          ),
          const SizedBox(height: 12),
        ],
        if (!skipsSms) ...[
          TextField(
            key: const Key('phone_verification_code'),
            controller: _codeController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (_) => _verify(),
            decoration: InputDecoration(
              labelText: context.tr('Verification code'),
              prefixIcon: const Icon(Icons.password_outlined),
            ),
          ),
        ],
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
        if (!skipsSms) ...[
          _PrimaryButton(
            _verifying ? 'Verifying…' : 'Verify phone number',
            onPressed: _verifying ? () {} : _verify,
          ),
          TextButton(
            onPressed: _sending || _verifying || _savingPhone
                ? null
                : () => _sendCode(resend: _codeSent),
            child: Text(
              _sending
                  ? 'Sending…'
                  : _codeSent
                  ? 'Resend code'
                  : 'Send verification code',
            ),
          ),
        ],
        TextButton.icon(
          key: const Key('phone_back_to_preferences'),
          onPressed: _sending || _verifying || _savingPhone
              ? null
              : _backToPreferences,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to dating preferences'),
        ),
      ],
    );
  }
}
