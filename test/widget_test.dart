import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material show Text;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:maplove/app.dart';
import 'package:maplove/config/supabase_config.dart';
import 'package:maplove/routes/app_routes.dart';
import 'package:maplove/services/external_checkout_service.dart';
import 'package:maplove/services/locale_service.dart';
import 'package:maplove/services/location_service.dart';
import 'package:maplove/services/maplov_repository.dart';

void main() {
  SupabaseConfig.forceUiOnlyForTesting = true;
  GeographyRepository.useForTesting(
    GeographyRepository.forTesting(
      countriesLoader: () async => const [
        GeographyCountry(id: 'ca', name: 'Canada', iso2: 'CA'),
        GeographyCountry(id: 'al', name: 'Albania', iso2: 'AL'),
        GeographyCountry(id: 'cm', name: 'Cameroon', iso2: 'CM'),
        GeographyCountry(id: 'fr', name: 'France', iso2: 'FR'),
        GeographyCountry(id: 'us', name: 'United States', iso2: 'US'),
      ],
      regionsLoader: (countryId) async => switch (countryId) {
        'ca' => const [
          GeographyRegion(id: 'ca-on', countryId: 'ca', name: 'Ontario'),
          GeographyRegion(id: 'ca-qc', countryId: 'ca', name: 'Quebec'),
        ],
        'cm' => const [
          GeographyRegion(id: 'cm-ce', countryId: 'cm', name: 'Centre'),
        ],
        'fr' => const [
          GeographyRegion(id: 'fr-idf', countryId: 'fr', name: 'Île-de-France'),
        ],
        _ => const [],
      },
      citiesLoader: (regionId) async => switch (regionId) {
        'ca-on' => const [
          GeographyCity(
            id: 'ca-on-toronto',
            regionId: 'ca-on',
            countryId: 'ca',
            name: 'Toronto',
          ),
          GeographyCity(
            id: 'ca-on-ottawa',
            regionId: 'ca-on',
            countryId: 'ca',
            name: 'Ottawa',
          ),
        ],
        'cm-ce' => const [
          GeographyCity(
            id: 'cm-ce-yaounde',
            regionId: 'cm-ce',
            countryId: 'cm',
            name: 'Yaoundé',
          ),
        ],
        'fr-idf' => const [
          GeographyCity(
            id: 'fr-idf-paris',
            regionId: 'fr-idf',
            countryId: 'fr',
            name: 'Paris',
          ),
        ],
        _ => const [],
      },
    ),
  );

  test('legacy Elite and current VIP tiers share the public VIP identity', () {
    expect(const SubscriptionInfo(tier: 'elite').isVip, isTrue);
    expect(const SubscriptionInfo(tier: 'elite').displayName, 'VIP');
    expect(const SubscriptionInfo(tier: 'vip').isVip, isTrue);
    expect(const SubscriptionInfo(tier: 'plus').isVip, isFalse);
  });

  test('premium catalog keeps included products visible for paid tiers', () {
    const plus = SubscriptionInfo(tier: 'plus');
    const vip = SubscriptionInfo(tier: 'vip');

    expect(
      storeProductIncludedLabel(plus, ExternalPaymentProduct.plusMonthly),
      'Inclus avec MapLov Plus',
    );
    expect(
      storeProductIncludedLabel(plus, ExternalPaymentProduct.countryPass24h),
      'Inclus avec MapLov Plus',
    );
    expect(
      storeProductIncludedLabel(plus, ExternalPaymentProduct.vipMonthly),
      isNull,
    );
    expect(
      storeProductIncludedLabel(
        vip,
        ExternalPaymentProduct.internationalPass7d,
      ),
      'Inclus avec MapLov VIP',
    );
    expect(
      storeProductIncludedLabel(vip, ExternalPaymentProduct.boost30m),
      isNull,
    );
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

  testWidgets('login removes Magic Link and remains scrollable when focused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Email me a Magic Link'), findsNothing);
    expect(find.byKey(const Key('login_scroll_view')), findsOneWidget);

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.drag(
      find.byKey(const Key('login_scroll_view')),
      const Offset(0, -220),
    );
    await tester.pump();

    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const Key('login_scroll_view')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('open reports metric opens the pending-only review page', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('admin_open_reports_metric')));
    await tester.pumpAndSettle();

    expect(find.text('Pending reports'), findsOneWidget);
    expect(find.text('Reports awaiting action'), findsOneWidget);
    expect(find.text('Profiles awaiting validation'), findsNothing);
  });

  testWidgets('admin user details identify the account before an action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AdminUserDetailsScreen(
          initialUser: {
            'id': '00000000-0000-4000-8000-000000000099',
            'first_name': 'Safety Target',
            'email': 'safety-target@maplov.test',
            'phone': '+14165550199',
            'role': 'user',
            'status': 'active',
            'city': 'Toronto',
            'country_name': 'Canada',
            'date_of_birth': '1992-04-05',
            'auth_created_at': '2026-07-01T12:00:00Z',
            'profile_created_at': '2026-07-01T12:00:00Z',
            'last_sign_in_at': '2026-07-30T15:00:00Z',
            'last_active_at': '2026-07-30T15:05:00Z',
            'open_reports': 2,
            'photo_count': 3,
            'subscription_tier': 'plus',
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Identity and contact'), findsOneWidget);
    expect(find.text('Last sign-in'), findsOneWidget);
    expect(find.text('Account created'), findsOneWidget);
    expect(find.text('safety-target@maplov.test'), findsWidgets);

    await tester.ensureVisible(find.text('Suspend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspend'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm account action'), findsOneWidget);
    expect(find.text('Safety Target'), findsWidgets);
    expect(find.text('+14165550199'), findsWidgets);
    expect(find.text('00000000-0000-4000-8000-000000000099'), findsWidgets);
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

  testWidgets('email verification requires a six-digit code', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.profileSetup: (_) =>
              const Scaffold(body: material.Text('Profile setup destination')),
        },
        home: const VerifyEmailScreen(email: 'jamie@example.com'),
      ),
    );

    expect(find.byKey(const Key('email_verification_code')), findsOneWidget);
    expect(
      find.text(
        'We sent a verification code to jamie@example.com. Enter it below to continue creating your profile.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('email_verification_code')),
      '123',
    );
    await tester.tap(find.text('Verify email'));
    await tester.pump();

    expect(find.text('Enter the verification code sent by email.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('email_verification_code')),
      '123456',
    );
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();

    expect(find.text('Profile setup destination'), findsOneWidget);
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

    final registrationScrollable = find.byType(Scrollable).first;
    expect(find.byKey(const Key('registration_geography_group')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('toggle_password')),
      200,
      scrollable: registrationScrollable,
    );

    expect(find.text('Phone number'), findsOneWidget);
    expect(find.byKey(const Key('phone_country_indicator')), findsOneWidget);
    final password = find.ancestor(
      of: find.byKey(const Key('toggle_password')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(password).obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle_password')));
    await tester.pump();
    expect(tester.widget<TextField>(password).obscureText, isFalse);
  });

  testWidgets(
    'registration hides geography and locks the phone code to GPS residence',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(dateOfBirth: DateTime(1990, 1, 1))),
      );

      expect(
        find.byKey(const Key('registration_geography_group')),
        findsNothing,
      );
      expect(find.text('Country of residence'), findsNothing);
      expect(find.text('Country of origin'), findsNothing);
      expect(find.byKey(const Key('phone_country_indicator')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('phone_country_indicator')),
          matching: find.byType(DropdownButton<String>),
        ),
        findsNothing,
      );
      expect(find.text('+1'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('phone_country_indicator')),
          matching: find.byIcon(Icons.lock_outline),
        ),
        findsOneWidget,
      );
    },
  );

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
    expect(find.text('Continue for now'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('phone_verification_code')),
      '123',
    );
    await tester.tap(find.text('Verify phone number'));
    await tester.pump();

    expect(find.text('Enter the verification code sent by SMS.'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('defer_phone_verification')));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('profile setup reuses residence and asks for origin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(
      find.text(
        'Your gender is saved during registration and cannot be changed later.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('private_reference_selfie'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text(
        'Your reference selfie is verified, kept private and never displayed on your profile.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('Current country of residence_region_Canada'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    final residenceCountry = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('Current country of residence_Canada'),
          skipOffstage: false,
        ),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(residenceCountry.onChanged, isNull);
    final residenceRegion = tester.widget<DropdownButton<String>>(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('Current country of residence_region_Canada'),
          skipOffstage: false,
        ),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    expect(residenceRegion.onChanged, isNotNull);
  });

  testWidgets('registration defers origin choices to profile setup', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(dateOfBirth: DateTime(1990, 1, 1))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Country of origin'), findsNothing);
    expect(find.text('City of origin'), findsNothing);

    await tester.pumpWidget(const MaterialApp(home: ProfileSetupScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Country of origin'), findsOneWidget);
    expect(find.text('City of origin'), findsOneWidget);
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
      find.text('Gender'),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.tap(find.text('Gender'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Woman').last);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.byKey(const Key('profile_setup_continue')),
      find.byType(ListView).first,
      const Offset(0, -250),
    );
    await tester.ensureVisible(find.byKey(const Key('profile_setup_continue')));
    await tester.pumpAndSettle();
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request access'));
    await tester.pumpAndSettle();
    expect(find.text('Premium Plus required'), findsOneWidget);
    expect(
      find.text(
        'Requesting access to secret albums requires a Premium Plus subscription.',
      ),
      findsOneWidget,
    );
    expect(find.text('Upgrade'), findsOneWidget);
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
    expect(find.text('Friends Posts'), findsNothing);
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
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('origin_profile_visibility_switch')),
          )
          .value,
      isTrue,
    );

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
    final quickScrollable = find
        .descendant(
          of: find.byKey(const Key('quick_filter_tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('near_me_country')),
      300,
      scrollable: quickScrollable,
    );
    expect(find.text('Search radius'), findsOneWidget);
    final countryTop = tester.getTopLeft(
      find.byKey(const Key('near_me_country')),
    );
    final regionTop = tester.getTopLeft(
      find.byKey(const Key('near_me_region')),
    );
    final cityTop = tester.getTopLeft(find.byKey(const Key('near_me_city')));
    expect(countryTop.dy, lessThan(regionTop.dy));
    expect(regionTop.dy, lessThan(cityTop.dy));

    await tester.scrollUntilVisible(
      find.byKey(const Key('location_mode_My country')),
      -300,
      scrollable: quickScrollable,
    );
    await tester.tap(find.byKey(const Key('location_mode_My country')));
    await tester.pumpAndSettle();
    expect(find.text('Premium Plus required'), findsOneWidget);
    expect(
      find.text('Country discovery requires a Premium Plus subscription.'),
      findsOneWidget,
    );
    expect(find.text('Upgrade'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('near_me_filter')), findsOneWidget);

    await tester.tap(find.byKey(const Key('location_mode_International')));
    await tester.pumpAndSettle();
    expect(find.text('Premium VIP required'), findsOneWidget);
    expect(
      find.text('International discovery requires a Premium VIP subscription.'),
      findsOneWidget,
    );
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
    await tester.scrollUntilVisible(
      find.byKey(const Key('preferences_back_to_profile')),
      200,
    );
    expect(
      find.byKey(const Key('preferences_back_to_profile')),
      findsOneWidget,
    );
  });

  testWidgets('preferences require one exclusive gender without Everyone', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PreferencesScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('gender_everyone')), findsNothing);
    for (final key in const [
      'gender_women',
      'gender_men',
      'gender_non_binary',
    ]) {
      expect(tester.widget<ChoiceChip>(find.byKey(Key(key))).selected, isFalse);
    }

    await tester.tap(find.byKey(const Key('gender_women')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('gender_women'))).selected,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('gender_men')));
    await tester.pump();
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('gender_women'))).selected,
      isFalse,
    );
    expect(
      tester.widget<ChoiceChip>(find.byKey(const Key('gender_men'))).selected,
      isTrue,
    );
  });

  testWidgets('profile silhouette selection is optional and single', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ProfileSetupScreen()));
    await tester.pumpAndSettle();

    final profileList = find.byType(ListView).first;
    await tester.dragUntilVisible(
      find.byKey(const Key('body_gallery_women')),
      profileList,
      const Offset(0, -300),
    );
    await tester.ensureVisible(find.byKey(const Key('body_gallery_women')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('body_gallery_women')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const Key('body_type_women_slim')),
      profileList,
      const Offset(0, -250),
    );
    await tester.ensureVisible(find.byKey(const Key('body_type_women_slim')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('body_type_women_slim')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('body_type_women_slim')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('body_type_women_toned')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('body_type_women_slim')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('body_type_women_toned')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('body_type_women_toned')));
    await tester.pump();
    expect(
      find.descendant(
        of: find.byKey(const Key('body_type_women_toned')),
        matching: find.byIcon(Icons.check),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'advanced silhouettes are distinct, validated, gated and reset together',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: FilterScreen(
            initialFilters: DiscoveryFilters(genders: ['Non-binary']),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Standard Filter'));
      await tester.pumpAndSettle();
      expect(find.text('Body type'), findsNothing);

      await tester.tap(find.text('Advanced Filter'));
      await tester.pumpAndSettle();
      expect(find.text('18 – 80'), findsOneWidget);
      final advancedList = find.descendant(
        of: find.byKey(const Key('advanced_filter_tab')),
        matching: find.byType(ListView),
      );
      await tester.dragUntilVisible(
        find.byKey(const Key('body_gallery_all_silhouettes')),
        advancedList,
        const Offset(0, -350),
      );
      await tester.ensureVisible(
        find.byKey(const Key('body_gallery_all_silhouettes')),
      );
      await tester.pumpAndSettle();

      final womenGallery = tester.widget<OutlinedButton>(
        find.byKey(const Key('body_gallery_women')),
      );
      final menGallery = tester.widget<OutlinedButton>(
        find.byKey(const Key('body_gallery_men')),
      );
      final allGallery = tester.widget<OutlinedButton>(
        find.byKey(const Key('body_gallery_all_silhouettes')),
      );
      expect(womenGallery.onPressed, isNull);
      expect(menGallery.onPressed, isNull);
      expect(allGallery.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('body_gallery_all_silhouettes')));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.byKey(const Key('body_type_all_women_slim')),
        advancedList,
        const Offset(0, -250),
      );
      await tester.ensureVisible(
        find.byKey(const Key('body_type_all_women_slim')),
      );
      await tester.pumpAndSettle();
      final bodyImages = tester.widgetList<Image>(find.byType(Image)).where((
        image,
      ) {
        final provider = image.image;
        return provider is AssetImage &&
            provider.assetName.startsWith('assets/body_types/');
      });
      expect(bodyImages, hasLength(16));

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.childAspectRatio, 0.75);

      Future<void> tapBody(String key) async {
        await tester.ensureVisible(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pump();
      }

      await tapBody('body_type_all_women_slim');
      expect(
        find.descendant(
          of: find.byKey(const Key('body_type_all_women_slim')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('body_type_all_men_slim')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );

      await tapBody('body_type_all_men_slim');
      await tapBody('body_type_all_women_toned');
      await tester.pump();
      for (final key in const [
        'body_type_all_women_slim',
        'body_type_all_men_slim',
        'body_type_all_women_toned',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
      }
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('body_type_no_preference')),
            )
            .selected,
        isFalse,
      );

      await tester.ensureVisible(
        find.byKey(const Key('body_type_validate_selection')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('body_type_validate_selection')));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);

      await tester.dragUntilVisible(
        find.byKey(const Key('body_gallery_all_silhouettes')),
        advancedList,
        const Offset(0, 500),
      );
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('body_gallery_all_silhouettes')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      tester
          .widget<ChoiceChip>(find.byKey(const Key('body_type_no_preference')))
          .onSelected!(true);
      await tester.pump();
      expect(find.byType(GridView), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const Key('body_type_no_preference')),
            )
            .selected,
        isTrue,
      );

      await tester.dragUntilVisible(
        find.byKey(const Key('body_gallery_all_silhouettes')),
        advancedList,
        const Offset(0, 500),
      );
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('body_gallery_all_silhouettes')),
          )
          .onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);
      for (final key in const [
        'body_type_all_women_slim',
        'body_type_all_men_slim',
        'body_type_all_women_toned',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byIcon(Icons.check),
          ),
          findsNothing,
        );
      }
    },
  );

  testWidgets('advanced filter restores the last saved criteria', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FilterScreen(
          initialFilters: DiscoveryFilters(
            minimumAge: 26,
            maximumAge: 64,
            genders: ['Woman'],
            bodyTypes: ['women_round'],
            religions: ['Buddhist'],
            eyeColors: ['Green'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced Filter'));
    await tester.pumpAndSettle();

    expect(find.text('26 – 64'), findsOneWidget);
    final advancedList = find.descendant(
      of: find.byKey(const Key('advanced_filter_tab')),
      matching: find.byType(ListView),
    );
    await tester.dragUntilVisible(
      find.byKey(const Key('body_gallery_women')),
      advancedList,
      const Offset(0, -350),
    );
    await tester.ensureVisible(find.byKey(const Key('body_gallery_women')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('body_gallery_women')))
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('body_gallery_men')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('body_gallery_all_silhouettes')),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('body_gallery_women')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('body_type_women_round')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('body_type_women_round')),
        matching: find.byIcon(Icons.check),
      ),
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
    final standardList = find.descendant(
      of: find.byKey(const Key('standard_filter_tab')),
      matching: find.byType(ListView),
    );
    final standardScrollable = find
        .descendant(
          of: find.byKey(const Key('standard_filter_tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Religion'),
      300,
      scrollable: standardScrollable,
    );
    expect(find.text('Religion'), findsOneWidget);
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
    final advancedScrollable = find
        .descendant(
          of: find.byKey(const Key('advanced_filter_tab')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('eye_color_blue')),
      500,
      scrollable: advancedScrollable,
    );
    await tester.ensureVisible(find.byKey(const Key('eye_color_blue')));
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
    await tester.ensureVisible(find.byKey(const Key('hair_color_brown')));
    await tester.pumpAndSettle();
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
    expect(appliedFilters?.originCountries, isEmpty);
    expect(appliedFilters?.languages, const ['French']);
    expect(appliedFilters?.requiredLanguages, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reset preserves the mandatory gender discovery filter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: FilterScreen(
          initialFilters: DiscoveryFilters(
            genders: ['Woman'],
            requiredGenders: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Women'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Women'), findsOneWidget);
  });

  testWidgets('Free origin filter opens the Premium Plus upgrade dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: FilterScreen()));
    final quickList = find.descendant(
      of: find.byKey(const Key('quick_filter_tab')),
      matching: find.byType(ListView),
    );
    await tester.drag(quickList, const Offset(0, -1250));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('origin_country_Any country')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Albania').last);
    await tester.pumpAndSettle();
    expect(find.text('Premium Plus required'), findsOneWidget);
    expect(
      find.text('Using origin filters requires a Premium Plus subscription.'),
      findsOneWidget,
    );
    expect(find.text('Upgrade'), findsOneWidget);
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
      isNotNull,
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
      showsOriginOnProfile: false,
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
      for (final product in ExternalPaymentProduct.values) {
        expect(find.byKey(Key('store_product_${product.id}')), findsOneWidget);
      }
      expect(find.text('KING'), findsOneWidget);
      expect(find.text('Invisible navigation in Discover'), findsOneWidget);
      expect(find.text(r'12,99 $ CAD'), findsOneWidget);
      expect(find.text(r'19,99 $ CAD'), findsOneWidget);
      expect(find.text(r'Économisez 55,89 $ (36 %)'), findsOneWidget);
      expect(find.text(r'Économisez 89,89 $ (37 %)'), findsOneWidget);
      expect(find.text('🏆 LE PLUS POPULAIRE'), findsOneWidget);
      expect(find.text('⭐ MEILLEURE OFFRE'), findsOneWidget);
      expect(find.text(r'Seulement 8,33 $ CAD / mois'), findsOneWidget);
      expect(find.text(r'Seulement 12,50 $ CAD / mois'), findsOneWidget);
      expect(find.textContaining('Prix affiché par Stripe'), findsNothing);
      expect(find.textContaining('À partir de'), findsNothing);
      expect(find.text(r'2,99 $ CAD'), findsNWidgets(3));
      expect(find.text(r'4,99 $ CAD'), findsNWidgets(2));
      expect(find.text(r'6,99 $ CAD'), findsNWidgets(2));
      expect(find.text(r'7,99 $ CAD'), findsOneWidget);
      expect(find.text(r'9,99 $ CAD'), findsOneWidget);
      expect(find.text(r'11,99 $ CAD'), findsOneWidget);
      expect(find.text(r'Pack de 30 • 0,40 $ par Super Like.'), findsOneWidget);
      expect(find.text('0 Super Likes disponibles'), findsOneWidget);
      expect(find.text('Aucun Boost actif'), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('store_product_maplov_plus_monthly')),
      );
      await tester.pumpAndSettle();
      expect(find.text('MapLov Plus mensuel'), findsWidgets);
      expect(find.text('Ce que vous obtenez'), findsOneWidget);
      expect(
        find.text('Voir qui a aimé et consulté votre profil'),
        findsOneWidget,
      );
      expect(
        find.text('Filtres avancés et recherche Country par région et ville'),
        findsOneWidget,
      );
      expect(find.text('S’abonner'), findsOneWidget);
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

  testWidgets(
    'arrival details render only when discovery supplies a destination',
    (tester) async {
      final arrivalProfile = UserProfile(
        id: 'arrival-profile',
        name: 'Marcel',
        age: 30,
        city: 'Toronto',
        country: 'Canada',
        compatibilityScore: 90,
        imagePath: 'assets/profile/profile_user_placeholder.png',
        photoDisplayStyle: PhotoDisplayStyle.profileDetails,
        isVip: true,
        arrivalCountry: 'France',
        arrivalRegion: 'Île-de-France',
        arrivalCity: 'Paris',
        arrivalMonth: DateTime(2027, 3),
      );
      await tester.pumpWidget(
        MaterialApp(home: PublicProfileScreen(profile: arrivalProfile)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('public_profile_arriving_soon')),
        findsOneWidget,
      );
      expect(
        find.textContaining('Paris, Île-de-France, France'),
        findsOneWidget,
      );

      const ordinaryView = UserProfile(
        id: 'ordinary-profile',
        name: 'Marcel',
        age: 30,
        city: 'Toronto',
        country: 'Canada',
        compatibilityScore: 90,
        imagePath: 'assets/profile/profile_user_placeholder.png',
        photoDisplayStyle: PhotoDisplayStyle.profileDetails,
        isVip: true,
      );
      await tester.pumpWidget(
        const MaterialApp(home: PublicProfileScreen(profile: ordinaryView)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('public_profile_arriving_soon')),
        findsNothing,
      );
      expect(find.textContaining('Arrive bientôt'), findsNothing);
    },
  );

  testWidgets('origin is hidden unless the profile owner enables it', (
    tester,
  ) async {
    const privateOrigin = UserProfile(
      id: 'private-origin',
      name: 'Alex',
      age: 30,
      city: 'Toronto',
      country: 'Canada',
      region: 'Ontario',
      originCountry: 'Cameroon',
      originRegion: 'Littoral',
      originCity: 'Douala',
      compatibilityScore: 90,
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
      showsOriginOnProfile: false,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PublicProfileScreen(profile: privateOrigin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Canada, Toronto'), findsOneWidget);
    expect(find.textContaining('Originally from'), findsNothing);
    expect(find.textContaining('Littoral'), findsNothing);

    const publicOrigin = UserProfile(
      id: 'public-origin',
      name: 'Sam',
      age: 31,
      city: 'Montréal',
      country: 'Canada',
      region: 'Québec',
      originCountry: 'Cameroon',
      originRegion: 'Centre',
      originCity: 'Yaoundé',
      showsOriginOnProfile: true,
      compatibilityScore: 88,
      imagePath: 'assets/profile/profile_user_placeholder.png',
      photoDisplayStyle: PhotoDisplayStyle.profileDetails,
    );
    await tester.pumpWidget(
      const MaterialApp(home: PublicProfileScreen(profile: publicOrigin)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Originally from Cameroon, Yaoundé'), findsOneWidget);
    expect(find.textContaining('Centre'), findsNothing);
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
    expect(find.text('Gender'), findsNothing);
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
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'City of origin',
    );
    final basicList = find.byKey(const Key('edit_profile_basic_tab'));
    await tester.scrollUntilVisible(
      cityOfOriginFinder,
      250,
      scrollable: find
          .descendant(of: basicList, matching: find.byType(Scrollable))
          .first,
    );
    final cityOfOrigin = tester.widget<DropdownButtonFormField<String>>(
      cityOfOriginFinder,
    );
    expect(cityOfOrigin.onChanged, isNull);
    final regionOfOrigin = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Region of origin',
      ),
    );
    expect(regionOfOrigin.onChanged, isNull);
  });

  testWidgets(
    'navigation exposes Posts and one combined Likes and Matches page',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pump();

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.text('Map'), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Likes & Matches'), findsOneWidget);
      final badge = tester.widget<Badge>(
        find.byKey(const Key('messages_navigation_badge')),
      );
      expect(badge.isLabelVisible, isFalse);
    },
  );

  testWidgets('Likes and Matches share one page with two tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ConnectionsScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('likes_matches_tabs')), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    expect(find.text('Matches'), findsOneWidget);
    expect(
      find.textContaining('People who liked your profile'),
      findsOneWidget,
    );

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Compatibility helps you'), findsOneWidget);
  });

  testWidgets('Create Post displays the current profile identity', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreatePostScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('create_post_author')), findsOneWidget);
    expect(find.text('Sophie'), findsOneWidget);
    expect(find.text('My profile'), findsNothing);
    expect(find.byKey(const Key('private_reference_selfie')), findsNothing);
    expect(
      find.byKey(const Key('photo_manager_reference_selfie')),
      findsNothing,
    );
    expect(find.textContaining('selfie'), findsNothing);
  });

  testWidgets('main discovery exposes the three subscription filters', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main_show_vip_only')), findsOneWidget);
    expect(find.byKey(const Key('main_show_premium_profiles')), findsOneWidget);
    expect(find.byKey(const Key('discover_tabs_scroll')), findsOneWidget);
    expect(
      find.byKey(const Key('discover_tab_Boutique MapLov')),
      findsOneWidget,
    );
    final subscriptionFilters = find.byKey(
      const Key('main_discovery_subscription_filters'),
    );
    await tester.drag(subscriptionFilters, const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('main_show_most_liked')), findsOneWidget);

    await tester.tap(find.byKey(const Key('main_show_most_liked')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.byKey(const Key('main_show_most_liked')))
          .selected,
      isTrue,
    );

    await tester.drag(subscriptionFilters, const Offset(700, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('main_show_vip_only')));
    await tester.pumpAndSettle();
    expect(find.text('Premium VIP required'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
  });

  testWidgets('Online discovery supports automatic and pull refresh', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen(initialTab: 'Online')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover_refresh_Online')), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

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
      'country_ids': ['ca'],
      'region_ids': ['ca-on'],
      'city_ids': ['ca-on-toronto'],
      'languages': ['French'],
      'relationship_goals': ['Marriage'],
      'genders': ['Women'],
      'personalities': ['Creative'],
      'interest_slugs': ['travel'],
      'body_types': ['women_slim', 'women_very_round'],
      'required_languages': true,
      'premium_only': true,
      'vip_only': true,
      'most_liked_first': true,
    });

    expect(filters.minimumAge, 25);
    expect(filters.countries, ['Canada']);
    expect(filters.countryIds, ['ca']);
    expect(filters.regionIds, ['ca-on']);
    expect(filters.cityIds, ['ca-on-toronto']);
    expect(filters.languages, ['French']);
    expect(filters.personalities, ['Creative']);
    expect(filters.interestSlugs, ['travel']);
    expect(filters.bodyTypes, ['women_slim', 'women_very_round']);
    expect(filters.requiredLanguages, isTrue);
    expect(filters.premiumOnly, isTrue);
    expect(filters.vipOnly, isTrue);
    expect(filters.mostLikedFirst, isTrue);
    expect(filters.toDatabase()['location_mode'], 'specific_country');
    expect(filters.toDatabase()['country_ids'], ['ca']);
    expect(filters.toDatabase()['region_ids'], ['ca-on']);
    expect(filters.toDatabase()['city_ids'], ['ca-on-toronto']);
    expect(filters.toDatabase()['premium_only'], isTrue);
    expect(filters.toDatabase()['vip_only'], isTrue);
    expect(filters.toDatabase()['most_liked_first'], isTrue);
    expect(filters.toDatabase()['body_types'], [
      'women_slim',
      'women_very_round',
    ]);
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

    expect(
      find.byKey(const Key('photo_manager_reference_selfie')),
      findsNothing,
    );
    expect(find.byKey(const Key('photo_manager_capture_selfie')), findsNothing);
    expect(find.text('Main'), findsNothing);
    expect(find.text('Set main'), findsNothing);
    expect(find.byTooltip('Move later'), findsNothing);
    expect(find.byTooltip('Move earlier'), findsNothing);
    expect(find.byTooltip('Delete photo'), findsNothing);
    expect(find.text('Profile photo'), findsOneWidget);
    expect(find.byTooltip('Use as profile photo'), findsWidgets);

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

  testWidgets('registration selfie enrollment asks for explicit consent', (
    tester,
  ) async {
    bool? accepted;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              accepted = await confirmFaceVerificationConsent(context);
            },
            child: const material.Text('Open consent'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open consent'));
    await tester.pumpAndSettle();
    expect(find.text('Private selfie verification'), findsOneWidget);
    expect(find.byKey(const Key('accept_face_verification')), findsOneWidget);
    await tester.tap(find.byKey(const Key('accept_face_verification')));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  test('face verification errors keep a safe user-facing message', () {
    const error = FaceVerificationException(
      'face_mismatch',
      'The face does not match the private reference selfie.',
    );
    expect(error.code, 'face_mismatch');
    expect(error.toString(), error.message);
    expect(error.rejectsRegistration, isFalse);

    const duplicate = FaceVerificationException(
      'duplicate_account_detected',
      'An account already exists.',
    );
    expect(duplicate.rejectsRegistration, isTrue);
  });

  testWidgets('non-VIP invisible navigation opens the VIP popup', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invisible_navigation_switch')));
    await tester.pumpAndSettle();

    expect(find.text('Premium VIP required'), findsOneWidget);
    expect(
      find.text('Invisible navigation requires a Premium VIP subscription.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Upgrade'), findsOneWidget);
  });

  test(
    'discovery region is persisted without becoming profile display text',
    () {
      final filters = DiscoveryFilters.fromDatabase({
        'country_codes': ['Canada'],
        'regions': ['Ontario'],
      });

      expect(filters.regions, ['Ontario']);
      expect(filters.toDatabase()['regions'], ['Ontario']);
      const profile = UserProfile(
        name: 'Jamie',
        age: 29,
        city: 'Toronto',
        country: 'Canada',
        region: 'Ontario',
        compatibilityScore: 90,
        imagePath: 'assets/profile/profile_user_placeholder.png',
        photoDisplayStyle: PhotoDisplayStyle.profileDetails,
      );
      expect('${profile.city}, ${profile.country}', 'Toronto, Canada');
    },
  );

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
      translations.translate(
        'We sent a verification code to jamie@example.com. Enter it below to continue creating your profile.',
      ),
      'Nous avons envoyé un code de vérification à jamie@example.com. Saisissez-le ci-dessous pour poursuivre la création de votre profil.',
    );
    expect(
      translations.translate('Feminine silhouette'),
      'Silhouette féminine',
    );
    expect(
      translations.translate('Masculine silhouette'),
      'Silhouette masculine',
    );
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
    'admin profiles': const AdminProfilesScreen(),
    'admin photos': const AdminPhotosScreen(),
    'admin suspensions': const AdminSuspensionsScreen(),
    'admin subscriptions': const AdminSubscriptionsScreen(),
    'admin payments': const AdminPaymentsScreen(),
    'admin promotions': const AdminPromotionsScreen(),
    'admin stripe catalog': const AdminStripeCatalogScreen(),
    'admin statistics': const AdminStatisticsScreen(),
    'admin global notifications': const AdminGlobalNotificationsScreen(),
    'admin account recovery': const AdminAccountRecoveryScreen(),
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
