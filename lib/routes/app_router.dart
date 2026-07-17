part of '../app.dart';

class AppRouter {
  const AppRouter._();

  static Widget _protected(Widget child) =>
      _AuthenticatedRouteGuard(child: child);

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
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
    AppRoutes.verifyEmail: (_) => const VerifyEmailScreen(),
    AppRoutes.verifyPhone: (_) => const VerifyPhoneScreen(),
    AppRoutes.deleteAccount: (_) => const DeleteAccountScreen(),
    AppRoutes.home: (_) => _protected(const HomeScreen()),
    AppRoutes.discover: (_) => _protected(const HomeScreen()),
    AppRoutes.nearMe: (_) => _protected(const HomeScreen(initialTab: 'Nearby')),
    AppRoutes.filters: (_) => _protected(const FilterScreen()),
    AppRoutes.matches: (_) => _protected(const MatchScreen()),
    AppRoutes.likes: (_) => _protected(const LikesScreen()),
    AppRoutes.newMatch: (_) => _protected(const MatchScreen()),
    AppRoutes.messages: (_) => _protected(const MessagesScreen()),
    AppRoutes.chat: (_) => _protected(const MessagesScreen()),
    AppRoutes.reportUser: (_) => _protected(const HomeScreen()),
    AppRoutes.blockUser: (_) => _protected(const HomeScreen()),
    AppRoutes.profile: (_) => _protected(const ProfileScreen()),
    AppRoutes.profileSetup: (_) => const ProfileSetupScreen(),
    AppRoutes.editProfile: (_) => const EditProfileScreen(),
    AppRoutes.managePhotos: (_) => const ManagePhotosScreen(),
    AppRoutes.preferences: (_) => const PreferencesScreen(),
    AppRoutes.publicProfile: (_) => _protected(const HomeScreen()),
    AppRoutes.compatibilityDetails: (_) => _protected(const MatchScreen()),
    AppRoutes.settings: (_) => _protected(const SettingsScreen()),
    AppRoutes.photoViewer: (_) => _protected(const ProfileScreen()),
    AppRoutes.friendRequests: (_) => const FriendRequestsScreen(),
    AppRoutes.friends: (_) => const FriendsListScreen(),
    AppRoutes.posts: (_) => _protected(const PostsScreen()),
    AppRoutes.createPost: (_) => const CreatePostScreen(),
    AppRoutes.postDetails: (_) => const PostsScreen(),
    AppRoutes.secretGarden: (_) => _protected(const SecretGardenScreen()),
    AppRoutes.gardenManagement: (_) => const GardenManagementScreen(),
    AppRoutes.gardenAccessRequests: (_) => const AccessRequestsScreen(),
    AppRoutes.gardenViewer: (_) => const GardenManagementScreen(),
    AppRoutes.premium: (_) => const PremiumScreen(),
    AppRoutes.subscriptionManagement: (_) =>
        const SubscriptionManagementScreen(),
    AppRoutes.purchaseStatus: (_) => const PurchaseStatusScreen(),
    AppRoutes.notifications: (_) => _protected(const NotificationsScreen()),
    AppRoutes.privacy: (_) => const PrivacyScreen(),
    AppRoutes.photoDisplaySettings: (_) => const PhotoDisplaySettingsScreen(),
    AppRoutes.security: (_) => const SecurityScreen(),
    AppRoutes.notificationSettings: (_) => const NotificationSettingsScreen(),
    AppRoutes.language: (_) => const LanguageScreen(),
    AppRoutes.blockedUsers: (_) => const BlockedUsersScreen(),
    AppRoutes.helpCenter: (_) => const HelpCenterScreen(),
    AppRoutes.legal: (_) => const LegalScreen(),
    AppRoutes.adminDashboard: (_) =>
        const _AdminRouteGuard(child: AdminDashboardScreen()),
    AppRoutes.moderationReports: (_) =>
        const _AdminRouteGuard(child: ModerationReportsScreen()),
    AppRoutes.adminUsers: (_) =>
        const _AdminRouteGuard(child: AdminUsersScreen()),
    AppRoutes.adminAudit: (_) =>
        const _AdminRouteGuard(child: AdminAuditScreen()),
  };
}

class _AuthenticatedRouteGuard extends StatelessWidget {
  const _AuthenticatedRouteGuard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AuthService.instance.hasActiveSession ||
        (!AuthService.instance.isConfigured && AppConfig.allowDemoData)) {
      return child;
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
