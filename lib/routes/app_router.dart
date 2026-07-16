part of '../app.dart';

class AppRouter {
  const AppRouter._();

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (_) => const SplashScreen(),
    AppRoutes.onboarding: (_) => const OnboardingScreen(),
    AppRoutes.login: (_) => const LoginScreen(),
    AppRoutes.register: (context) {
      final argument = ModalRoute.of(context)?.settings.arguments;
      return RegisterScreen(
        dateOfBirth: argument is DateTime ? argument : null,
      );
    },
    AppRoutes.ageGate: (_) => const AgeGateScreen(),
    AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
    AppRoutes.resetPassword: (_) => const ResetPasswordScreen(),
    AppRoutes.verifyEmail: (_) => const VerifyEmailScreen(),
    AppRoutes.verifyPhone: (_) => const VerifyPhoneScreen(),
    AppRoutes.deleteAccount: (_) => const DeleteAccountScreen(),
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.discover: (_) => const HomeScreen(),
    AppRoutes.nearMe: (_) => const HomeScreen(initialTab: 'Nearby'),
    AppRoutes.filters: (_) => const FilterScreen(),
    AppRoutes.matches: (_) => const MatchScreen(),
    AppRoutes.likes: (_) => const LikesScreen(),
    AppRoutes.newMatch: (_) => const NewMatchScreen(),
    AppRoutes.messages: (_) => const MessagesScreen(),
    AppRoutes.chat: (_) => const ChatScreen(),
    AppRoutes.reportUser: (_) => const ReportUserScreen(),
    AppRoutes.blockUser: (_) => const BlockUserScreen(),
    AppRoutes.profile: (_) => const ProfileScreen(),
    AppRoutes.profileSetup: (_) => const ProfileSetupScreen(),
    AppRoutes.editProfile: (_) => const EditProfileScreen(),
    AppRoutes.managePhotos: (_) => const ManagePhotosScreen(),
    AppRoutes.preferences: (_) => const PreferencesScreen(),
    AppRoutes.publicProfile: (_) => const PublicProfileScreen(),
    AppRoutes.compatibilityDetails: (_) => const CompatibilityDetailsScreen(),
    AppRoutes.settings: (_) => const SettingsScreen(),
    AppRoutes.photoViewer: (_) => const PhotoViewerScreen(),
    AppRoutes.friendRequests: (_) => const FriendRequestsScreen(),
    AppRoutes.friends: (_) => const FriendsListScreen(),
    AppRoutes.posts: (_) => const PostsScreen(),
    AppRoutes.createPost: (_) => const CreatePostScreen(),
    AppRoutes.postDetails: (_) => const PostDetailsScreen(),
    AppRoutes.secretGarden: (_) => const SecretGardenScreen(),
    AppRoutes.gardenManagement: (_) => const GardenManagementScreen(),
    AppRoutes.gardenAccessRequests: (_) => const AccessRequestsScreen(),
    AppRoutes.gardenViewer: (_) => const GardenViewerScreen(),
    AppRoutes.premium: (_) => const PremiumScreen(),
    AppRoutes.subscriptionManagement: (_) =>
        const SubscriptionManagementScreen(),
    AppRoutes.purchaseStatus: (_) => const PurchaseStatusScreen(),
    AppRoutes.notifications: (_) => const NotificationsScreen(),
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
