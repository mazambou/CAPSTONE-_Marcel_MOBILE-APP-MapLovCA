import 'package:flutter/material.dart';

import 'data/mock_data.dart';
import 'models/user_profile.dart';
import 'routes/app_routes.dart';
import 'shared/theme/app_colors.dart';

export 'models/user_profile.dart';
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
part 'shared/widgets/app_widgets.dart';

class MapLoveApp extends StatelessWidget {
  const MapLoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MapLov',
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
    );
  }
}
