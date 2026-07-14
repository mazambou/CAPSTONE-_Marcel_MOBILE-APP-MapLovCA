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

  testWidgets('login validates credentials and signs in in local UI mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (_) => const HomeScreen()},
        home: const LoginScreen(),
      ),
    );

    await tester.tap(find.text('Log In'));
    await tester.pump();
    expect(
      find.text('Enter your email or phone and password.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).at(0), 'jamie@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'Password!1');
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('password reset rejects a weak password', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ResetPasswordScreen()));

    await tester.enterText(find.byType(TextField).first, 'weak');
    await tester.enterText(find.byType(TextField).last, 'weak');
    await tester.tap(find.text('Update password'));
    await tester.pump();

    expect(
      find.text('Use at least 8 characters, including a number and a symbol.'),
      findsOneWidget,
    );
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
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
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

  testWidgets('opens Standard and Advanced filters with Show Results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FilterScreen()));

    await tester.tap(find.text('Standard Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Religion'), findsOneWidget);
    final standardList = find.descendant(
      of: find.byKey(const Key('standard_filter_tab')),
      matching: find.byType(ListView),
    );
    await tester.drag(standardList, const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('standard_show_results')), findsOneWidget);

    await tester.tap(find.text('Advanced Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Basic'), findsOneWidget);
    final advancedList = find.descendant(
      of: find.byKey(const Key('advanced_filter_tab')),
      matching: find.byType(ListView),
    );
    await tester.drag(advancedList, const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('advanced_show_results')), findsOneWidget);
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

  testWidgets('premium comparison renders all plans on a wide viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 1536);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PremiumScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Upgrade to Premium'), findsOneWidget);
    expect(find.text('FREE'), findsOneWidget);
    expect(find.text('PREMIUM\nPLUS'), findsOneWidget);
    expect(find.text('PREMIUM\nELITE'), findsOneWidget);
    expect(find.text('PREMIUM\nVIP'), findsOneWidget);
    expect(find.text('MOST POPULAR'), findsOneWidget);
    expect(find.text('NEW'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit profile exposes attributes used by discovery filters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
    await tester.tap(find.text('Profile details'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('edit_profile_filter_details_tab')),
      findsOneWidget,
    );
    expect(find.text('Basic matching information'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
    final detailsList = find.byKey(
      const Key('edit_profile_filter_details_tab'),
    );
    await tester.scrollUntilVisible(
      find.text('Religion'),
      300,
      scrollable: find
          .descendant(of: detailsList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Religion'), findsOneWidget);
    expect(find.text('Children preference'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'navigation uses search for Discover and replaces Map with Matches',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.text('Matches'), findsOneWidget);
    },
  );

  testWidgets('new match page keeps the message and discovery actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: NewMatchScreen()));

    expect(find.text("It's a Match!"), findsOneWidget);
    expect(find.byKey(const Key('new_match_send_message')), findsOneWidget);
    expect(find.byKey(const Key('new_match_keep_swiping')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'profile exposes album management without removing photo previews',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
      await tester.scrollUntilVisible(
        find.byKey(const Key('manage_album_button')),
        250,
      );

      expect(find.byKey(const Key('manage_album_button')), findsOneWidget);
      expect(find.text('Photos'), findsOneWidget);
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
    'new match': const NewMatchScreen(),
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
    'admin users': const AdminUsersScreen(),
    'admin audit': const AdminAuditScreen(),
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
