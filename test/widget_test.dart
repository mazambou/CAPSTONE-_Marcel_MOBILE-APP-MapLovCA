import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';
import 'package:maplove/routes/app_routes.dart';
import 'package:maplove/services/locale_service.dart';
import 'package:maplove/services/location_service.dart';
import 'package:maplove/services/maplov_repository.dart';

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;

  test('legacy Elite and current VIP tiers share the public VIP identity', () {
    expect(const SubscriptionInfo(tier: 'elite').isVip, isTrue);
    expect(const SubscriptionInfo(tier: 'elite').displayName, 'VIP');
    expect(const SubscriptionInfo(tier: 'vip').isVip, isTrue);
    expect(const SubscriptionInfo(tier: 'plus').isVip, isFalse);
  });

  test('New Account visibility follows the 7/7/14 day rollout', () {
    final now = DateTime.utc(2026, 7, 17);
    bool visible(int days, String tier, {bool owner = false}) =>
        newAccountVisibleToTier(
          createdAt: now.subtract(Duration(days: days)),
          viewerTier: tier,
          isOwner: owner,
          now: now,
        );

    expect(visible(2, 'free'), isFalse);
    expect(visible(2, 'plus'), isFalse);
    expect(visible(2, 'vip'), isTrue);
    expect(visible(9, 'free'), isFalse);
    expect(visible(9, 'plus'), isTrue);
    expect(visible(16, 'free'), isTrue);
    expect(visible(2, 'free', owner: true), isTrue);
  });

  test(
    'international discovery opt-out only affects international searches',
    () {
      bool visible(String mode, {bool owner = false}) =>
          visibleInInternationalDiscovery(
            allowsInternationalDiscovery: false,
            isOwner: owner,
            locationMode: mode,
          );

      expect(visible('specific_country'), isFalse);
      expect(visible('worldwide'), isFalse);
      expect(visible('near_me'), isTrue);
      expect(visible('my_country'), isTrue);
      expect(visible('specific_country', owner: true), isTrue);
    },
  );

  test('photo engagement combines likes, Super Likes and comments', () {
    const profile = UserProfile(
      name: 'Engagement',
      age: 25,
      city: 'Toronto',
      compatibilityScore: 80,
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoUrls: ['one', 'two'],
      photoLikeCounts: [10, 4],
      photoSuperLikeCounts: [2, 8],
      photoCommentCounts: [3, 5],
      photoDisplayStyle: PhotoDisplayStyle.social,
    );
    expect(profile.engagementScore, 17);
  });

  test(
    'Nearby distinguishes retryable and settings-only location failures',
    () {
      expect(
        const MapLovLocationFailure(
          MapLovLocationFailureReason.denied,
        ).requiresSettings,
        isFalse,
      );
      expect(
        const MapLovLocationFailure(
          MapLovLocationFailureReason.deniedForever,
        ).requiresSettings,
        isTrue,
      );
      expect(
        const MapLovLocationFailure(
          MapLovLocationFailureReason.serviceDisabled,
        ).requiresSettings,
        isTrue,
      );
    },
  );

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

  testWidgets('age gate requires every versioned legal acceptance', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AgeGateScreen()));
    await tester.scrollUntilVisible(find.text('Continue'), 300);
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    expect(find.text('Terms of Use', skipOffstage: false), findsOneWidget);
    expect(find.text('Privacy Policy', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Community Guidelines', skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byType(CheckboxListTile, skipOffstage: false),
      findsNWidgets(5),
    );
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

  testWidgets('phone country controls the locked residence dropdown', (
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
    expect(countryDropdown.onChanged, isNull);
    expect(
      find.byKey(const ValueKey('registration_city_dropdown_Canada')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('registration_city_dropdown_Canada')),
        matching: find.text('Toronto'),
      ),
      findsOneWidget,
    );
    final canadianCityDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('registration_city_dropdown_Canada')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(canadianCityDropdown.items!.length, greaterThan(150));

    final phoneIndicator = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('phone_country_indicator')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    phoneIndicator.onChanged!('France');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('registration_city_dropdown_France')),
      findsOneWidget,
    );
    expect(find.text('Paris'), findsOneWidget);
    final frenchPhoneIndicator = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('phone_country_indicator')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(frenchPhoneIndicator.value, 'France');
    expect(find.text('+33'), findsOneWidget);

    frenchPhoneIndicator.onChanged!('Cameroon');
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
    final cameroonCityDropdown = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const ValueKey('registration_city_dropdown_Cameroon')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(
      cameroonCityDropdown.items!.map((item) => item.value).toList(),
      const [
        'Douala',
        'Yaoundé',
        'Garoua',
        'Bamenda',
        'Maroua',
        'Bafoussam',
        'Ngaoundéré',
        'Kumba',
        'Limbe',
        'Bertoua',
        'Ebolowa',
        'Kribi',
        'Nkongsamba',
        'Foumban',
        'Dschang',
        'Mbouda',
        'Edéa',
        'Kousséri',
        'Kumbo',
        'Bafang',
        'Other city',
      ],
    );
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

  testWidgets('profile setup reuses residence and asks for origin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileSetupScreen()));
    await tester.pumpAndSettle();

    expect(find.text('First name'), findsNothing);
    expect(find.text('Date of birth'), findsNothing);
    expect(find.text('Current residence', skipOffstage: false), findsOneWidget);
    expect(find.text('Your origin', skipOffstage: false), findsOneWidget);
    expect(
      find.text('Current country of residence', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Country of origin', skipOffstage: false), findsOneWidget);
    expect(find.text('City of origin', skipOffstage: false), findsOneWidget);
  });

  testWidgets('registration saves country and city of origin together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(dateOfBirth: DateTime(1990, 1, 1))),
    );

    final originCountry = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(const Key('registration_origin_country_dropdown')),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    originCountry.onChanged!('France');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('registration_origin_city_dropdown_France')),
      findsOneWidget,
    );
    expect(find.text('City of origin'), findsOneWidget);
    expect(find.text('Paris'), findsOneWidget);
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

  testWidgets(
    'most-liked strip opens the owner display and arrows follow strip order',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byKey(const Key('popular_photos_strip')), findsOneWidget);
      expect(find.text('Most liked photos'), findsOneWidget);
      expect(find.byKey(const Key('popular_photos_list')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popular_photos_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('popular_photos_list')), findsNothing);
      expect(find.text('Most liked photos'), findsOneWidget);

      await tester.tap(find.byKey(const Key('popular_photos_toggle')));
      await tester.pump();
      expect(find.byKey(const Key('popular_photos_list')), findsOneWidget);

      await tester.tap(
        find.byKey(
          const Key('popular_photo_00000000-0000-4000-8000-000000000002-0'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(PhotoViewerScreen), findsNWidgets(2));
      expect(find.text('Alex, 30'), findsWidgets);
      expect(find.byKey(const Key('social_photo_comment')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('Taylor, 29'), findsWidgets);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(find.text('Sophie, 27'), findsWidgets);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    },
  );

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
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('secret_garden_album')));
    await tester.pumpAndSettle();

    expect(find.byType(SecretGardenScreen), findsOneWidget);
    expect(find.text('Request access'), findsOneWidget);
  });

  testWidgets('creates a Secret Garden album without breaking dialog state', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GardenManagementScreen()));
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Create private album'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Private memories');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create private album'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner can add photos from inside a Secret Garden album', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GardenViewerScreen(
          album: GardenAlbumItem(
            id: 'owner-garden',
            ownerId: 'owner',
            title: 'Private memories',
          ),
          canManageAlbum: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add_secret_garden_photos')), findsOneWidget);
    expect(find.text('Add photos'), findsOneWidget);
  });

  testWidgets('shows personal community actions only on My Profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.scrollUntilVisible(
      find.byKey(const Key('personal_recent_activity')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('My Friends'), findsOneWidget);
    expect(find.text('Friends Posts'), findsOneWidget);
    expect(find.text('Recent activity'), findsOneWidget);
  });

  testWidgets('profile can disable international discovery', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pump();

    final finder = find.byKey(const Key('international_discovery_switch'));
    expect(finder, findsOneWidget);
    expect(tester.widget<SwitchListTile>(finder).value, isTrue);

    await tester.tap(finder);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
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
    expect(
      find.byKey(
        const ValueKey<String>('origin_country_Any country'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

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
    await tester.drag(advancedList, const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('eye_color_blue')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('eye_color_blue')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('hair_color_brown')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('hair_color_brown')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.drag(advancedList, const Offset(0, -8000));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('advanced_show_results')), findsOneWidget);
  });

  testWidgets('Show Results applies filters and returns to discovery', (
    tester,
  ) async {
    DiscoveryFilters? appliedFilters;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const Key('open_filters_for_result'),
              onPressed: () async {
                appliedFilters = await Navigator.push<DiscoveryFilters>(
                  context,
                  MaterialPageRoute(builder: (_) => const FilterScreen()),
                );
              },
              child: const Icon(Icons.tune),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_filters_for_result')));
    await tester.pumpAndSettle();
    final quickList = find.descendant(
      of: find.byKey(const Key('quick_filter_tab')),
      matching: find.byType(ListView),
    );
    final quickScrollable = find
        .descendant(
          of: find.byKey(const Key('quick_filter_tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey<String>('origin_country_Any country'),
        skipOffstage: false,
      ),
      250,
      scrollable: quickScrollable,
    );
    final originDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(
        const ValueKey<String>('origin_country_Any country'),
        skipOffstage: false,
      ),
    );
    originDropdown.onChanged!('Cameroon');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('quick_language_filter')),
      250,
      scrollable: quickScrollable,
    );
    final languageDropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const Key('quick_language_filter')),
    );
    languageDropdown.onChanged!('French');
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('quick_show_results')),
      quickList,
      const Offset(0, -300),
    );
    await tester.tap(find.byKey(const Key('quick_show_results')));
    await tester.pumpAndSettle();

    expect(find.byType(FilterScreen), findsNothing);
    expect(find.byKey(const Key('open_filters_for_result')), findsOneWidget);
    expect(appliedFilters?.originCountries, const ['Cameroon']);
    expect(appliedFilters?.languages, const ['French']);
    expect(appliedFilters?.requiredLanguages, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('country-of-origin filtering matches complete profile data', () async {
    final profiles = await MapLovRepository.instance.discoverProfiles(
      filters: const DiscoveryFilters(originCountries: ['Cameroon']),
    );

    expect(profiles.map((profile) => profile.name), contains('Sophie'));
    expect(
      profiles.every((profile) => profile.originCountry == 'Cameroon'),
      isTrue,
    );
  });

  test('Nearby uses the selected radius instead of a fixed distance', () async {
    final profiles = await MapLovRepository.instance.discoverProfiles(
      tab: 'Nearby',
      filters: const DiscoveryFilters(distanceKm: 5, requiredLocation: true),
    );

    expect(
      profiles.map((profile) => profile.name),
      containsAll(['Sophie', 'Alex']),
    );
    expect(profiles.every((profile) => profile.distanceKm <= 5), isTrue);
  });

  test('Nearby combines distance and country-of-origin filters', () async {
    final profiles = await MapLovRepository.instance.discoverProfiles(
      tab: 'Nearby',
      filters: const DiscoveryFilters(
        distanceKm: 5,
        originCountries: ['Cameroon'],
        requiredLocation: true,
      ),
    );

    expect(profiles.map((profile) => profile.name), ['Sophie']);
    expect(
      profiles.every(
        (profile) =>
            profile.distanceKm <= 5 && profile.originCountry == 'Cameroon',
      ),
      isTrue,
    );
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
              photoLikeCounts: [24],
              photoSuperLikeCounts: [3],
              photoCommentCounts: [2],
            ),
            displayStyleOverride: PhotoDisplayStyle.social,
          ),
        ),
      );

      expect(find.byKey(const Key('social_photo_like')), findsOneWidget);
      expect(find.byKey(const Key('social_photo_comment')), findsOneWidget);
      expect(find.byKey(const Key('social_photo_super_like')), findsOneWidget);
      expect(
        find.byKey(const Key('photo_comment_count_badge')),
        findsOneWidget,
      );
      expect(find.text('2 Comments'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsNothing);

      await tester.tap(find.byKey(const Key('social_photo_like')));
      await tester.pump();
      expect(find.text('25 Liked'), findsOneWidget);

      await tester.tap(find.byKey(const Key('social_photo_comment')));
      await tester.pumpAndSettle();
      expect(find.text('Comments on Morgan’s photo'), findsOneWidget);
    },
  );

  testWidgets('chat reference layout keeps text messaging functional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Compatibility'), findsNothing);
    expect(find.byKey(const Key('chat_match_badge')), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
    expect(
      tester
          .widget<ListView>(find.byKey(const Key('chat_message_list')))
          .reverse,
      isFalse,
    );

    await tester.enterText(
      find.byKey(const Key('chat_message_field')),
      'Reference chat test',
    );
    await tester.pump();
    expect(find.byIcon(Icons.send), findsOneWidget);
    expect(find.byKey(const Key('chat_voice_action')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_primary_action')));
    await tester.pumpAndSettle();

    expect(find.text('Reference chat test'), findsOneWidget);
    await tester.tap(find.text('Reference chat test'));
    await tester.pumpAndSettle();
    expect(find.text('Delete message?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete for me'));
    await tester.pumpAndSettle();
    expect(find.text('Reference chat test'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('chat_message_field')),
      'Clearable message',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_primary_action')));
    await tester.pumpAndSettle();
    expect(find.text('Clearable message'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear chat').last);
    await tester.pumpAndSettle();
    expect(find.text('Clear chat?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Clear for everyone'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Clear for me'));
    await tester.pumpAndSettle();

    expect(find.text('Clearable message'), findsNothing);
    expect(find.text('Chat cleared.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat profile header opens the matching public profile', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'chat-profile-link-test',
      name: 'Avery',
      age: 31,
      city: 'Ottawa',
      compatibilityScore: 87,
      imagePath: 'assets/avatars/story_02.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    );
    await tester.pumpWidget(
      const MaterialApp(home: ChatScreen(profile: profile)),
    );
    await tester.pumpAndSettle();

    expect(find.text('87% Match'), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat_profile_link')));
    await tester.pumpAndSettle();

    expect(find.byType(PublicProfileScreen), findsOneWidget);
    expect(find.text('Avery, 31'), findsWidgets);
  });

  testWidgets('emoji panel inserts at cursor and send ignores rapid taps', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();

    final sendButton = tester.widget<IconButton>(
      find.byKey(const Key('chat_primary_action')),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('chat_message_field')),
      'Hello world',
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('chat_message_field')),
    );
    field.controller!.selection = const TextSelection.collapsed(offset: 5);
    await tester.tap(find.byKey(const Key('chat_emoji_action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_emoji_panel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat_emoji_Love_0')));
    await tester.pump();
    expect(field.controller!.text, 'Hello❤️ world');

    await tester.tap(find.byKey(const Key('chat_primary_action')));
    await tester.tap(find.byKey(const Key('chat_primary_action')));
    await tester.pumpAndSettle();

    expect(find.text('Hello❤️ world'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat attachment menu keeps photos and adds documents', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ChatScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.attach_file));
    await tester.pumpAndSettle();

    expect(find.text('Choose a photo'), findsOneWidget);
    expect(find.text('Choose a document'), findsOneWidget);
  });

  testWidgets('detailed photo viewer toggles an uncluttered focus mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: PhotoViewerScreen(
          profile: UserProfile(
            id: 'focus-photo-test',
            name: 'Morgan',
            age: 29,
            city: 'Toronto',
            compatibilityScore: 75,
            imagePath: 'assets/avatars/story_02.png',
            photoDisplayStyle: PhotoDisplayStyle.profileDetails,
          ),
        ),
      ),
    );

    expect(find.text('About me'), findsOneWidget);
    await tester.tapAt(const Offset(195, 360));
    await tester.pump();
    expect(find.text('About me'), findsNothing);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    expect(find.byKey(const Key('super_like_love_icon')), findsOneWidget);
    expect(find.byKey(const Key('report_current_photo')), findsOneWidget);

    await tester.tapAt(const Offset(195, 360));
    await tester.pump();
    expect(find.text('About me'), findsOneWidget);
  });

  testWidgets('profile exposes the two photo display choices', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/settings/photo-display': (_) => const PhotoDisplaySettingsScreen(),
        },
        home: const ProfileScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile_photo_display_button')),
      300,
    );
    await tester.tap(find.byKey(const Key('profile_photo_display_button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('photo_display_profile_details')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('photo_display_social')), findsOneWidget);
  });

  testWidgets('a profile photo can only be reported once per account', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'photo-report-profile',
      name: 'Taylor',
      age: 30,
      city: 'Montréal',
      compatibilityScore: 88,
      imagePath: 'assets/avatars/story_02.png',
      photoUrls: ['assets/avatars/story_02.png'],
      photoIds: ['photo-report-once'],
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PhotoViewerScreen(profile: profile)),
    );
    await tester.pumpAndSettle();

    Future<void> reportPhoto() async {
      await tester.tap(find.byKey(const Key('report_current_photo')));
      await tester.pumpAndSettle();
      expect(find.text('Report this photo?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    await reportPhoto();
    expect(find.text('Photo reported for review.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await reportPhoto();
    expect(find.text('You have already reported this photo.'), findsOneWidget);
  });

  testWidgets(
    'premium comparison renders Free, Plus and the consolidated VIP',
    (tester) async {
      tester.view.physicalSize = const Size(1024, 1536);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: PremiumScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to Premium'), findsOneWidget);
      expect(find.text('FREE'), findsOneWidget);
      expect(find.text('PREMIUM\nPLUS'), findsOneWidget);
      expect(find.text('PREMIUM\nVIP'), findsOneWidget);
      expect(find.text('PREMIUM\nELITE'), findsNothing);
      expect(find.text('KING'), findsOneWidget);
      expect(find.text('Invisible navigation in Discover'), findsOneWidget);
      expect(find.text(r'$19.99'), findsOneWidget);
      expect(find.text(r'$29.99'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a VIP account displays its public king badge', (tester) async {
    const profile = UserProfile(
      id: 'vip-profile',
      name: 'Alex',
      age: 30,
      city: 'Toronto',
      compatibilityScore: 90,
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
      isVip: true,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PublicProfileScreen(profile: profile)),
    );
    await tester.pumpAndSettle();
    expect(find.text('VIP'), findsOneWidget);
  });

  testWidgets('public profile can send and cancel a friend request', (
    tester,
  ) async {
    const profile = UserProfile(
      id: 'friend-action-target',
      name: 'Friend target',
      age: 31,
      city: 'Toronto',
      compatibilityScore: 82,
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PublicProfileScreen(profile: profile)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('public_profile_friend_action')),
      300,
    );

    expect(find.text('Add friend'), findsOneWidget);
    await tester.tap(find.byKey(const Key('public_profile_friend_action')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel request'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('public_profile_friend_action')));
    await tester.pumpAndSettle();
    expect(find.text('Add friend'), findsOneWidget);
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
    expect(
      find.text('Children preference', skipOffstage: false),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('city of origin is read-only after account creation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: EditProfileScreen()));
    await tester.pumpAndSettle();
    final cityOfOriginFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'City of origin',
    );
    final basicList = find.byKey(const Key('edit_profile_basic_tab'));
    await tester.scrollUntilVisible(
      cityOfOriginFinder,
      250,
      scrollable: find
          .descendant(of: basicList, matching: find.byType(Scrollable))
          .first,
    );
    final cityOfOrigin = tester.widget<TextField>(cityOfOriginFinder);
    expect(cityOfOrigin.enabled, isFalse);
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

  testWidgets('profile photos stay inside the album until it is opened', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        routes: {AppRoutes.managePhotos: (_) => const ManagePhotosScreen()},
        home: const ProfileScreen(),
      ),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('manage_album_button')),
      250,
    );

    expect(find.byKey(const Key('my_profile_photo_0')), findsNothing);
    expect(find.byKey(const Key('manage_album_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('manage_album_button')));
    await tester.pumpAndSettle();

    expect(find.byType(ManagePhotosScreen), findsOneWidget);
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

  test('stored age preferences are normalized to the slider limits', () {
    final reversed = DiscoveryFilters.fromDatabase({
      'minimum_age': 95,
      'maximum_age': 12,
    });

    expect(reversed.minimumAge, 80);
    expect(reversed.maximumAge, 80);
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

  testWidgets('photo manager keeps clean thumbnails until a long press', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ManagePhotosScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Main'), findsNothing);
    expect(find.text('Set main'), findsNothing);
    expect(find.byTooltip('Move later'), findsNothing);
    expect(find.byTooltip('Move earlier'), findsNothing);
    expect(find.byTooltip('Delete photo'), findsNothing);

    final firstPhoto = find
        .byWidgetPredicate(
          (widget) =>
              widget is GestureDetector &&
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'managed_photo_',
              ),
        )
        .first;
    expect(firstPhoto, findsOneWidget);
    final photoKey =
        tester.widget<GestureDetector>(firstPhoto).key! as ValueKey<String>;
    final photoId = photoKey.value.replaceFirst('managed_photo_', '');
    await tester.longPress(firstPhoto);
    await tester.pump();

    expect(find.byKey(Key('delete_managed_photo_$photoId')), findsOneWidget);
  });

  test('French translations are centralized', () {
    const translations = MapLovLocalizations(Locale('fr'));
    expect(translations.translate('Settings'), 'Paramètres');
    expect(translations.translate('Manage photos'), 'Gérer les photos');
    expect(
      translations.translate('Unable to apply filters: network error'),
      'Impossible d’appliquer les filtres : network error',
    );
    expect(translations.translate('2 Comments'), '2 commentaires');
    expect(
      translations.translate('Unknown dynamic content'),
      'Unknown dynamic content',
    );
  });

  test('saved language wins and device language is the first-run default', () {
    expect(
      LocaleService.resolveInitialLocale(
        savedLanguageCode: null,
        deviceLocale: const Locale('fr', 'CA'),
      ),
      const Locale('fr'),
    );
    expect(
      LocaleService.resolveInitialLocale(
        savedLanguageCode: null,
        deviceLocale: const Locale('es'),
      ),
      const Locale('en'),
    );
    expect(
      LocaleService.resolveInitialLocale(
        savedLanguageCode: 'en',
        deviceLocale: const Locale('fr', 'CA'),
      ),
      const Locale('en'),
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

  testWidgets('legal documents, data export and help content are actionable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LegalScreen()));
    await tester.tap(find.text('Community Guidelines'));
    await tester.pumpAndSettle();
    expect(find.text('Respect and consent'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(key: UniqueKey(), home: const HelpCenterScreen()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('help_search')), 'delete');
    await tester.pump();
    expect(find.text('Exporting or deleting your data'), findsOneWidget);
    expect(find.text('Creating and verifying an account'), findsNothing);
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
