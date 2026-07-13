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
    AppRoutes.deleteAccount: (_) => const DeleteAccountScreen(),
    AppRoutes.home: (_) => const HomeScreen(),
    AppRoutes.discover: (_) => const DiscoverScreen(),
    AppRoutes.nearMe: (_) => const NearMeScreen(),
    AppRoutes.filters: (_) => const FilterScreen(),
    AppRoutes.matches: (_) => const MatchScreen(),
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
    AppRoutes.adminDashboard: (_) => const AdminDashboardScreen(),
    AppRoutes.moderationReports: (_) => const ModerationReportsScreen(),
    AppRoutes.adminUsers: (_) => const AdminUsersScreen(),
    AppRoutes.adminAudit: (_) => const AdminAuditScreen(),
  };
}
