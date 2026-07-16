import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material show Text, TextDirection;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'data/mock_data.dart';
import 'models/user_profile.dart';
import 'routes/app_routes.dart';
import 'services/auth_service.dart';
import 'services/locale_service.dart';
import 'services/location_service.dart';
import 'services/maplov_repository.dart';
import 'services/purchase_service.dart';
import 'shared/theme/app_colors.dart';

export 'models/user_profile.dart';
export 'services/locale_service.dart' show MapLovLocalizations;
export 'services/maplov_repository.dart'
    show
        DiscoveryFilters,
        MapLovRepository,
        MatchItem,
        ProfileLikeResult,
        SubscriptionInfo;
import 'pages/onboarding/onboarding_page.dart';
import 'pages/splash/splash_page.dart';

part 'routes/app_router.dart';
part 'pages/auth/login_page.dart';
part 'pages/auth/register_page.dart';
part 'pages/auth/age_gate_page.dart';
part 'pages/auth/delete_account_page.dart';
part 'pages/auth/forgot_password_page.dart';
part 'pages/auth/reset_password_page.dart';
part 'pages/auth/verify_email_page.dart';
part 'pages/auth/verify_phone_page.dart';
part 'pages/auth/widgets/auth_widgets.dart';
part 'pages/community/posts_page.dart';
part 'pages/community/create_post_page.dart';
part 'pages/community/friends_list_page.dart';
part 'pages/community/post_details_page.dart';
part 'pages/discovery/discover_page.dart';
part 'pages/discovery/filter_page.dart';
part 'pages/discovery/near_me_page.dart';
part 'pages/home/home_page.dart';
part 'pages/matching/match_page.dart';
part 'pages/matching/likes_page.dart';
part 'pages/messaging/chat_page.dart';
part 'pages/messaging/messages_page.dart';
part 'pages/premium/premium_page.dart';
part 'pages/premium/subscription_management_page.dart';
part 'pages/premium/purchase_status_page.dart';
part 'pages/profile/friend_requests_page.dart';
part 'pages/profile/edit_profile_page.dart';
part 'pages/profile/manage_photos_page.dart';
part 'pages/profile/preferences_page.dart';
part 'pages/profile/photo_viewer_page.dart';
part 'pages/profile/profile_setup_page.dart';
part 'pages/profile/profile_page.dart';
part 'pages/profile/public_profile_page.dart';
part 'pages/matching/compatibility_details_page.dart';
part 'pages/safety/block_user_page.dart';
part 'pages/safety/report_user_page.dart';
part 'pages/secret_garden/secret_garden_page.dart';
part 'pages/secret_garden/access_requests_page.dart';
part 'pages/secret_garden/garden_management_page.dart';
part 'pages/secret_garden/garden_viewer_page.dart';
part 'pages/settings/settings_page.dart';
part 'pages/settings/blocked_users_page.dart';
part 'pages/settings/help_center_page.dart';
part 'pages/settings/language_page.dart';
part 'pages/settings/legal_page.dart';
part 'pages/settings/notification_settings_page.dart';
part 'pages/settings/privacy_page.dart';
part 'pages/settings/photo_display_settings_page.dart';
part 'pages/settings/security_page.dart';
part 'pages/notifications/notifications_page.dart';
part 'pages/admin/admin_dashboard_page.dart';
part 'pages/admin/moderation_reports_page.dart';
part 'pages/admin/admin_users_page.dart';
part 'pages/admin/admin_audit_page.dart';
part 'shared/widgets/app_widgets.dart';

/// Keeps every plain screen label on the same bilingual translation path.
/// User-generated values that are not present in the catalogue stay unchanged.
class Text extends StatelessWidget {
  const Text(
    String this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    InlineSpan this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.semanticsIdentifier,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final InlineSpan? textSpan;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final String? semanticsIdentifier;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final translatedSemantics = semanticsLabel == null
        ? null
        : context.tr(semanticsLabel!);
    if (textSpan != null) {
      return material.Text.rich(
        textSpan!,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: translatedSemantics,
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return material.Text(
      context.tr(data!),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: translatedSemantics,
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

class MapLoveApp extends StatefulWidget {
  const MapLoveApp({super.key});

  @override
  State<MapLoveApp> createState() => _MapLoveAppState();
}

class _MapLoveAppState extends State<MapLoveApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<MapLovAuthEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(LocaleService.instance.load());
    unawaited(PurchaseService.instance.initialize());
    _authSubscription = AuthService.instance.events.listen((event) {
      if (event == MapLovAuthEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushNamed(AppRoutes.resetPassword);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LocaleService.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'MapLov',
        locale: LocaleService.instance.locale,
        supportedLocales: const [Locale('en'), Locale('fr')],
        localizationsDelegates: const [
          MapLovLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.coral,
            primary: AppColors.coral,
            surface: AppColors.white,
          ),
          scaffoldBackgroundColor: AppColors.white,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.lightGray,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        initialRoute: AppRoutes.splash,
        routes: AppRouter.routes,
      ),
    );
  }
}

ImageProvider<Object> profileImageProvider(UserProfile profile) =>
    profile.hasNetworkImage
    ? NetworkImage(profile.imagePath)
    : AssetImage(profile.imagePath);

Widget profileImage(
  UserProfile profile, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) => profile.hasNetworkImage
    ? Image.network(
        profile.imagePath,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/profile/profile_user_placeholder.png',
          fit: fit,
          width: width,
          height: height,
        ),
      )
    : Image.asset(profile.imagePath, fit: fit, width: width, height: height);

Widget mediaImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  Alignment alignment = Alignment.center,
  double? width,
  double? height,
}) => path.startsWith('http')
    ? Image.network(
        path,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
      )
    : Image.asset(
        path,
        fit: fit,
        alignment: alignment,
        width: width,
        height: height,
      );
