part of '../app.dart';

class AppRouter {
  const AppRouter._();

  static Widget _protected(
    Widget child, {
    bool allowPendingPhoneVerification = false,
  }) => _AuthenticatedRouteGuard(
    allowPendingPhoneVerification: allowPendingPhoneVerification,
    child: child,
  );

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.onboarding: (_) => const OnboardingScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (context) {
      final argument = ModalRoute.of(context)?.settings.arguments;
      return RegisterScreen(
        gateData: argument is RegistrationGateData ? argument : null,
      );
    },
    AppRoutes.ageGate: (_) => const AgeGateScreen(),
    AppRoutes.socialAgeGate: (_) =>
        const AgeGateScreen(completeExistingSocialAccount: true),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.magicLink: (_) => const MagicLinkScreen(),
    AppRoutes.authCallback: (_) => const AuthCallbackScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
    AppRoutes.verifyEmail: (_) => const VerifyEmailScreen(),
    AppRoutes.verifyPhone: (_) => const VerifyPhoneScreen(),
    AppRoutes.deleteAccount: (_) => _protected(const DeleteAccountScreen()),
    AppRoutes.home: (_) => _protected(const HomeScreen()),
    AppRoutes.discover: (_) => _protected(const HomeScreen()),
    AppRoutes.nearMe: (_) => _protected(const HomeScreen(initialTab: 'Nearby')),
    AppRoutes.filters: (_) => _protected(const FilterScreen()),
    AppRoutes.matches: (_) =>
        _protected(const ConnectionsScreen(initialTab: 1)),
    AppRoutes.likes: (_) => _protected(const ConnectionsScreen()),
    AppRoutes.newMatch: (_) => _protected(const MatchScreen()),
    AppRoutes.messages: (_) => _protected(const MessagesScreen()),
    AppRoutes.chat: (_) => _protected(const MessagesScreen()),
    AppRoutes.reportUser: (_) => _protected(const HomeScreen()),
    AppRoutes.blockUser: (_) => _protected(const HomeScreen()),
    AppRoutes.profile: (_) => _protected(const ProfileScreen()),
    AppRoutes.profileSetup: (_) => _protected(
      const ProfileSetupScreen(),
      allowPendingPhoneVerification: true,
    ),
    AppRoutes.editProfile: (_) => _protected(const EditProfileScreen()),
    AppRoutes.managePhotos: (_) => _protected(const ManagePhotosScreen()),
    AppRoutes.preferences: (_) => _protected(
      const PreferencesScreen(),
      allowPendingPhoneVerification: true,
    ),
    AppRoutes.publicProfile: (_) => _protected(const HomeScreen()),
    AppRoutes.compatibilityDetails: (_) => _protected(const MatchScreen()),
    AppRoutes.settings: (_) => _protected(const SettingsScreen()),
    AppRoutes.photoViewer: (_) => _protected(const ProfileScreen()),
    AppRoutes.friendRequests: (_) => _protected(const FriendRequestsScreen()),
    AppRoutes.friends: (_) => _protected(const FriendsListScreen()),
    AppRoutes.addFriends: (_) => _protected(const AddFriendsScreen()),
    AppRoutes.posts: (_) => _protected(const PostsScreen()),
    AppRoutes.createPost: (_) => _protected(const CreatePostScreen()),
    AppRoutes.postDetails: (_) => _protected(const PostsScreen()),
    AppRoutes.secretGarden: (_) => _protected(const SecretGardenScreen()),
    AppRoutes.gardenManagement: (_) =>
        _protected(const GardenManagementScreen()),
    AppRoutes.gardenAccessRequests: (_) =>
        _protected(const AccessRequestsScreen()),
    AppRoutes.gardenViewer: (_) => _protected(const GardenManagementScreen()),
    AppRoutes.premium: (_) => _protected(const PremiumScreen()),
    AppRoutes.subscriptionManagement: (_) =>
        _protected(const SubscriptionManagementScreen()),
    AppRoutes.purchaseStatus: (_) => _protected(const PurchaseStatusScreen()),
    AppRoutes.externalCheckoutReturn: (_) =>
        _protected(const ExternalCheckoutReturnScreen()),
    AppRoutes.notifications: (_) => _protected(const NotificationsScreen()),
    AppRoutes.privacy: (_) => _protected(const PrivacyScreen()),
    AppRoutes.photoDisplaySettings: (_) =>
        _protected(const PhotoDisplaySettingsScreen()),
    AppRoutes.security: (_) => _protected(const SecurityScreen()),
    AppRoutes.changeEmail: (_) => _protected(const ChangeEmailScreen()),
    AppRoutes.notificationSettings: (_) =>
        _protected(const NotificationSettingsScreen()),
    AppRoutes.language: (_) => _protected(const LanguageScreen()),
    AppRoutes.blockedUsers: (_) => _protected(const BlockedUsersScreen()),
    AppRoutes.helpCenter: (_) => _protected(const HelpCenterScreen()),
    AppRoutes.legal: (_) => _protected(const LegalScreen()),
    AppRoutes.adminDashboard: (_) =>
        const _AdminRouteGuard(child: AdminDashboardScreen()),
    AppRoutes.moderationReports: (_) =>
        const _AdminRouteGuard(child: ModerationReportsScreen()),
    AppRoutes.adminUsers: (_) =>
        const _AdminRouteGuard(child: AdminUsersScreen()),
    AppRoutes.adminAudit: (_) =>
        const _AdminRouteGuard(child: AdminAuditScreen()),
  };

  /// Resolves query-bearing web callbacks by path while preserving arguments.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final path = Uri.tryParse(settings.name ?? '')?.path;
    final builder = path == null ? null : routes[path];
    if (builder == null) return null;
    return MaterialPageRoute<void>(
      builder: builder,
      settings: RouteSettings(name: path, arguments: settings.arguments),
    );
  }

  /// Prevents Flutter from constructing intermediate routes such as `/auth`
  /// when the browser starts directly at `/auth/callback`.
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    final callback = onGenerateRoute(RouteSettings(name: initialRoute));
    if (callback != null) return [callback];
    return [
      MaterialPageRoute<void>(
        builder: routes[AppRoutes.splash]!,
        settings: const RouteSettings(name: AppRoutes.splash),
      ),
    ];
  }
}

class _AuthenticatedRouteGuard extends StatefulWidget {
  const _AuthenticatedRouteGuard({
    required this.child,
    this.allowPendingPhoneVerification = false,
  });
  final Widget child;
  final bool allowPendingPhoneVerification;

  @override
  State<_AuthenticatedRouteGuard> createState() =>
      _AuthenticatedRouteGuardState();
}

class _AuthenticatedRouteGuardState extends State<_AuthenticatedRouteGuard> {
  Future<bool>? _phoneRequirement;
  Future<Map<String, dynamic>?>? _pendingNotice;
  bool _acknowledgingNotice = false;
  String? _noticeError;

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.hasActiveSession &&
        AuthService.instance.isConfigured) {
      _pendingNotice = MapLovRepository.instance.pendingAdminNotice();
    }
    if (!widget.allowPendingPhoneVerification &&
        AuthService.instance.hasActiveSession) {
      _phoneRequirement = AuthService.instance
          .requiresPhoneVerificationForCurrentUser();
    }
  }

  Future<void> _acknowledgeNotice(String noticeId) async {
    if (_acknowledgingNotice) return;
    setState(() {
      _acknowledgingNotice = true;
      _noticeError = null;
    });
    try {
      await MapLovRepository.instance.acknowledgeAdminNotice(noticeId);
      if (!mounted) return;
      setState(() {
        _pendingNotice = MapLovRepository.instance.pendingAdminNotice();
        _acknowledgingNotice = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _acknowledgingNotice = false;
        _noticeError = context.tr('Could not confirm this warning. Try again.');
      });
    }
  }

  Widget _noticeLoading() =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));

  Widget _noticeFailure() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Could not load your account notice.')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() {
                _pendingNotice = MapLovRepository.instance.pendingAdminNotice();
              }),
              child: Text(context.tr('Try again')),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _noticeDialog(Map<String, dynamic> notice) => PopScope(
    canPop: false,
    child: Scaffold(
      body: Stack(
        children: [
          const ModalBarrier(color: Colors.black54, dismissible: false),
          Center(
            child: AlertDialog(
              title: Text(context.tr('Message from MapLov moderation')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notice['body'] as String? ?? ''),
                    if (_noticeError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _noticeError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: _acknowledgingNotice
                      ? null
                      : () => _acknowledgeNotice(notice['id'] as String),
                  child: Text(context.tr('OK')),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _authenticatedContent() {
    if (widget.allowPendingPhoneVerification ||
        !AuthService.instance.isConfigured) {
      return widget.child;
    }
    return FutureBuilder<bool>(
      future: _phoneRequirement,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _noticeLoading();
        if (snapshot.data == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.verifyPhone,
              (_) => false,
            );
          });
          return _noticeLoading();
        }
        return widget.child;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.hasActiveSession ||
        (!AuthService.instance.isConfigured && AppConfig.allowDemoData)) {
      if (!AuthService.instance.isConfigured) return widget.child;
      _pendingNotice ??= MapLovRepository.instance.pendingAdminNotice();
      return FutureBuilder<Map<String, dynamic>?>(
        future: _pendingNotice,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _noticeLoading();
          }
          if (snapshot.hasError) return _noticeFailure();
          final notice = snapshot.data;
          if (notice != null) return _noticeDialog(notice);
          return _authenticatedContent();
        },
      );
    }
    if (!AuthService.instance.isConfigured) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'MapLov production configuration is unavailable. Please install an official build or contact support.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _AdminRouteGuard extends StatelessWidget {
  const _AdminRouteGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
    future: MapLovRepository.instance.currentAccount(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final role = snapshot.data?['role'] as String?;
      if (role != 'admin' && role != 'moderator') {
        return Scaffold(
          appBar: AppBar(title: const Text('Access denied')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('This page is restricted to the moderation team.'),
            ),
          ),
        );
      }
      return child;
    },
  );
}
