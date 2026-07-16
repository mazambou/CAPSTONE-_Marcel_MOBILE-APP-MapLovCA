import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

  testWidgets('birth calendar exposes year arrows and a scrollable year list', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AgeGateScreen()));
    await tester.tap(find.text('Date of birth'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('previous_birth_year')), findsOneWidget);
    expect(find.byKey(const Key('next_birth_year')), findsOneWidget);
    expect(find.byKey(const Key('select_birth_year')), findsOneWidget);

    await tester.tap(find.byKey(const Key('select_birth_year')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('birth_year_list')), findsOneWidget);
  });

  testWidgets('registration passwords can be shown and hidden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(dateOfBirth: DateTime(1990, 1, 1))),
    );

    expect(find.text('Phone number'), findsOneWidget);
    expect(find.byKey(const Key('phone_country_indicator')), findsOneWidget);
    final password = find.byType(TextField).at(3);
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle_password')));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
  });

  testWidgets('registration country controls the city dropdown', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(dateOfBirth: DateTime(1990, 1, 1))),
    );

    expect(
      find.byKey(const Key('registration_country_dropdown')),
      findsOneWidget,
    );
    final countryDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('registration_country_dropdown')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(countryDropdown.items!.length, greaterThanOrEqualTo(190));
    expect(
      find.byKey(const ValueKey('registration_city_dropdown_Canada')),
      findsOneWidget,
    );
    expect(find.text('Toronto'), findsOneWidget);

    countryDropdown.onChanged!('France');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('registration_city_dropdown_France')),
      findsOneWidget,
    );
    expect(find.text('Paris'), findsOneWidget);
    final phoneIndicator = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('phone_country_indicator')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(phoneIndicator.value, 'France');
    expect(find.text('+33'), findsOneWidget);

    phoneIndicator.onChanged!('Cameroon');
    await tester.pumpAndSettle();
    final synchronizedCountry = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('registration_country_dropdown')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(synchronizedCountry.value, 'Cameroon');
    expect(find.text('Douala'), findsOneWidget);
    expect(find.text('+237'), findsOneWidget);
  });

  testWidgets('phone verification requires a six-digit code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/home': (_) => const HomeScreen()},
        home: const VerifyPhoneScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('phone_number_being_verified')),
      findsOneWidget,
    );
    expect(find.text('Phone number being verified'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('defer_phone_verification')), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('phone_verification_code')),
      '123',
    );
    await tester.tap(find.text('Verify phone number'));
    await tester.pump();

    expect(find.text('Enter the 6-digit code sent by SMS.'), findsOneWidget);
  });

  testWidgets('profile setup does not ask registration details twice', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSetupScreen()));
    await tester.pumpAndSettle();

    expect(find.text('First name'), findsNothing);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('City'), findsNothing);
    expect(find.text('Country'), findsNothing);
    expect(find.text('Gender'), findsOneWidget);
  });

  testWidgets('profile setup can continue without uploading a photo', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {'/profile/preferences': (_) => const PreferencesScreen()},
        home: const ProfileSetupScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('profile_setup_continue')),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.tap(find.byKey(const Key('profile_setup_continue')));
    await tester.pumpAndSettle();

    expect(find.byType(PreferencesScreen), findsOneWidget);
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

  testWidgets('preferences reuses the geographic filter selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PreferencesScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('location_mode_Near me')), findsOneWidget);
    expect(find.byKey(const Key('location_mode_My country')), findsOneWidget);
    expect(
      find.byKey(const Key('location_mode_International')),
      findsOneWidget,
    );
    expect(find.text('Search radius'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Next'), 300);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.byKey(const Key('preferences_back_to_profile')),
      findsOneWidget,
    );
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
            profile: UserProfile(
              id: 'social-photo-test',
              name: 'Morgan',
              age: 29,
              city: 'Toronto',
              compatibilityScore: 75,
              imagePath: 'assets/avatars/story_02.png',
              photoDisplayStyle: PhotoDisplayStyle.social,
            ),
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
      expect(find.text('Comments on Morgan’s photo'), findsOneWidget);
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
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('Likes'), findsOneWidget);
    },
  );

  testWidgets('incoming like must be opened before liking back', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LikesScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('incoming_like_photo_Sophie')), findsOneWidget);
    expect(find.byKey(const Key('grid_like_Sophie')), findsNothing);

    await tester.tap(find.byKey(const Key('incoming_like_photo_Sophie')));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.byKey(const Key('photo_profile_like_Sophie')), findsOneWidget);

    await tester.tap(find.byKey(const Key('photo_profile_like_Sophie')));
    await tester.pumpAndSettle();
    expect(find.byType(NewMatchScreen), findsOneWidget);

    await MapLovRepository.instance.toggleProfileLike(
      '00000000-0000-4000-8000-000000000001',
    );
  });

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

  testWidgets('my photo opens the current account instead of a mock profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.tap(find.byKey(const Key('my_profile_photo_0')));
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text('Jamie, 29'), findsOneWidget);
    expect(find.text('Sophie, 27'), findsNothing);
  });

  test('discovery preferences keep all V1 criteria', () {
    final filters = DiscoveryFilters.fromDatabase({
      'minimum_age': 25,
      'maximum_age': 40,
      'location_mode': 'specific_country',
      'country_codes': ['Canada'],
      'languages': ['French'],
      'relationship_goals': ['Marriage'],
      'genders': ['Women'],
      'personalities': ['Creative'],
      'interest_slugs': ['travel'],
      'required_languages': true,
    });

    expect(filters.minimumAge, 25);
    expect(filters.countries, ['Canada']);
    expect(filters.languages, ['French']);
    expect(filters.personalities, ['Creative']);
    expect(filters.interestSlugs, ['travel']);
    expect(filters.requiredLanguages, isTrue);
    expect(filters.toDatabase()['location_mode'], 'specific_country');
  });

  test('demo likes are persistent and create a mutual match', () async {
    const profileId = '00000000-0000-4000-8000-000000000001';
    final first = await MapLovRepository.instance.toggleProfileLike(profileId);
    expect(first.liked, isTrue);
    expect(first.matched, isTrue);

    final matches = await MapLovRepository.instance.myMatches();
    expect(matches.any((item) => item.profile.id == profileId), isTrue);

    final removed = await MapLovRepository.instance.toggleProfileLike(
      profileId,
    );
    expect(removed.liked, isFalse);
  });

  test('reciprocal photo likes create a new match', () async {
    const profileId = '00000000-0000-4000-8000-000000000001';
    final result = await MapLovRepository.instance.togglePhotoLike(
      'demo-photo-$profileId',
      profileId: profileId,
      currentlyLiked: false,
    );

    expect(result.liked, isTrue);
    expect(result.matched, isTrue);
    final matches = await MapLovRepository.instance.myMatches();
    expect(matches.any((item) => item.profile.id == profileId), isTrue);

    await MapLovRepository.instance.togglePhotoLike(
      'demo-photo-$profileId',
      profileId: profileId,
      currentlyLiked: true,
    );
  });

  testWidgets('compatibility details use the selected profile score', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'dynamic-score',
      name: 'Morgan',
      age: 31,
      city: 'Ottawa',
      compatibilityScore: 73,
      compatibilityBreakdown: {
        'preferences': 75,
        'interests': 60,
        'relationship': 90,
        'languages': 80,
        'geography': 70,
        'shared_interests': 2,
        'shared_languages': 1,
      },
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    );
    await tester.pumpWidget(
      const MaterialApp(home: CompatibilityDetailsScreen(profile: profile)),
    );

    expect(find.text('73%'), findsOneWidget);
    expect(find.text('2 shared interests.'), findsOneWidget);
  });

  testWidgets('photo manager exposes main-photo and ordering controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ManagePhotosScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Main'), findsOneWidget);
    expect(find.text('Set main'), findsWidgets);
    expect(find.byTooltip('Move later'), findsWidgets);
  });

  test('French translations are centralized', () {
    const translations = MapLovLocalizations(Locale('fr'));
    expect(translations.translate('Settings'), 'Paramètres');
    expect(translations.translate('Manage photos'), 'Gérer les photos');
    expect(
      translations.translate('Unknown dynamic content'),
      'Unknown dynamic content',
    );
  });

  testWidgets('screen labels render in French and English', (tester) async {
    Future<void> render(Locale locale) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          MapLovLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsScreen(),
      ),
    );

    await render(const Locale('fr'));
    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.text('Confidentialité'), findsOneWidget);

    await render(const Locale('en'));
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });

  test(
    'demo user flows cover blocking, friendship, posts and Garden',
    () async {
      final repository = MapLovRepository.instance;
      final target = (await repository.discoverProfiles()).last;

      await repository.unblockUser(target.id);
      await repository.blockUser(target.id);
      expect(
        (await repository.blockedUsers()).any(
          (profile) => profile.id == target.id,
        ),
        isTrue,
      );
      expect(
        (await repository.discoverProfiles()).any(
          (profile) => profile.id == target.id,
        ),
        isFalse,
      );
      await repository.unblockUser(target.id);

      await repository.sendFriendRequest(target.id);
      expect(
        (await repository.friendships(
          status: 'pending',
        )).any((friendship) => friendship.profile.id == target.id),
        isTrue,
      );
      await repository.removeFriendship(target.id, cancel: true);

      const body = 'Automated private post flow';
      await repository.createPost(body: body, commentsEnabled: true);
      final post = (await repository.posts()).firstWhere(
        (item) => item.body == body,
      );
      await repository.deletePost(post.id);
      expect(
        (await repository.posts()).any((item) => item.id == post.id),
        isFalse,
      );

      final albums = await repository.gardenAlbums(ownerId: target.id);
      expect(albums.single.ownerId, target.id);
      await repository.requestGardenAccess(albums.single.id, 600);
    },
  );

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'age gate': const AgeGateScreen(),
    'forgot password': const ForgotPasswordScreen(),
    'reset password': const ResetPasswordScreen(),
    'verify email': const VerifyEmailScreen(),
    'verify phone': const VerifyPhoneScreen(),
    'delete account': const DeleteAccountScreen(),
    'home': const HomeScreen(),
    'discover': const DiscoverScreen(),
    'near me': const NearMeScreen(),
    'filters': const FilterScreen(),
    'matches': const MatchScreen(),
    'likes': const LikesScreen(),
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
