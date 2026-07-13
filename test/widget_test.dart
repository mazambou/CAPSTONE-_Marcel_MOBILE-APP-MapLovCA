import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/app.dart';

void main() {
  testWidgets('shows splash then navigates to onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MapLoveApp());

    expect(find.byKey(const Key('splash_screen')), findsOneWidget);
    expect(find.text('Find Love Near You'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Find Love Near You'), findsOneWidget);
  });

  testWidgets('opens the full-screen gallery when a profile photo is tapped', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.byKey(const Key('profile_photo_Sophie')));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text('Sophie, 27'), findsOneWidget);
    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('opens a public profile from the person name', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.tap(find.byKey(const Key('profile_name_Sophie')));
    await tester.pumpAndSettle();

    expect(find.byType(PublicProfileScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Photo albums'), 250);
    expect(find.text('Public Photos'), findsOneWidget);
    expect(find.text('Secret Garden'), findsOneWidget);
  });

  testWidgets('opens the access request from the Secret Garden album', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/secret-garden': (_) => const SecretGardenScreen()},
        home: const PublicProfileScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('secret_garden_album')),
      250,
    );
    await tester.tap(find.byKey(const Key('secret_garden_album')));
    await tester.pumpAndSettle();

    expect(find.byType(SecretGardenScreen), findsOneWidget);
    expect(find.text('Request access'), findsOneWidget);
  });

  testWidgets('shows personal community actions only on My Profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pumpAndSettle();

    expect(find.text('My Friends'), findsOneWidget);
    expect(find.text('Friends Posts'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('switches between the three geographic filter modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FilterScreen()));
    expect(find.text('Search radius'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location_mode_My country')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my_country_city_dropdown')), findsOneWidget);
    expect(find.text('City in Canada'), findsOneWidget);

    await tester.tap(find.byKey(const Key('location_mode_International')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('international_country_dropdown')),
      findsOneWidget,
    );
    expect(find.text('International search'), findsOneWidget);
  });

  testWidgets(
    'social photo display supports likes and comments without share',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PhotoViewerScreen(
            displayStyleOverride: PhotoDisplayStyle.social,
          ),
        ),
      );

      expect(find.byKey(const Key('social_photo_like')), findsOneWidget);
      expect(find.byKey(const Key('social_photo_comment')), findsOneWidget);
      expect(find.byKey(const Key('social_photo_super_like')), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);

      await tester.tap(find.byKey(const Key('social_photo_like')));
      await tester.pump();
      expect(find.text('25 Liked'), findsOneWidget);

      await tester.tap(find.byKey(const Key('social_photo_comment')));
      await tester.pumpAndSettle();
      expect(find.text('Comments on Sophie’s photo'), findsOneWidget);
    },
  );

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'age gate': const AgeGateScreen(),
    'forgot password': const ForgotPasswordScreen(),
    'reset password': const ResetPasswordScreen(),
    'verify email': const VerifyEmailScreen(),
    'delete account': const DeleteAccountScreen(),
    'home': const HomeScreen(),
    'discover': const DiscoverScreen(),
    'near me': const NearMeScreen(),
    'filters': const FilterScreen(),
    'matches': const MatchScreen(),
    'messages': const MessagesScreen(),
    'chat': const ChatScreen(),
    'report user': const ReportUserScreen(),
    'block user': const BlockUserScreen(),
    'profile': const ProfileScreen(),
    'profile setup': const ProfileSetupScreen(),
    'edit profile': const EditProfileScreen(),
    'manage photos': const ManagePhotosScreen(),
    'preferences': const PreferencesScreen(),
    'public profile': const PublicProfileScreen(),
    'compatibility details': const CompatibilityDetailsScreen(),
    'settings': const SettingsScreen(),
    'photo viewer': const PhotoViewerScreen(),
    'social photo viewer': const PhotoViewerScreen(
      displayStyleOverride: PhotoDisplayStyle.social,
    ),
    'friend requests': const FriendRequestsScreen(),
    'friends list': const FriendsListScreen(),
    'posts': const PostsScreen(),
    'create post': const CreatePostScreen(),
    'post details': const PostDetailsScreen(),
    'secret garden': const SecretGardenScreen(),
    'garden management': const GardenManagementScreen(),
    'garden access requests': const AccessRequestsScreen(),
    'garden viewer': const GardenViewerScreen(),
    'premium': const PremiumScreen(),
    'subscription management': const SubscriptionManagementScreen(),
    'purchase status': const PurchaseStatusScreen(),
    'notifications': const NotificationsScreen(),
    'privacy': const PrivacyScreen(),
    'photo display settings': const PhotoDisplaySettingsScreen(),
    'security': const SecurityScreen(),
    'notification settings': const NotificationSettingsScreen(),
    'language': const LanguageScreen(),
    'blocked users': const BlockedUsersScreen(),
    'help center': const HelpCenterScreen(),
    'legal': const LegalScreen(),
    'admin dashboard': const AdminDashboardScreen(),
    'moderation reports': const ModerationReportsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders on a mobile viewport', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: entry.value));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
