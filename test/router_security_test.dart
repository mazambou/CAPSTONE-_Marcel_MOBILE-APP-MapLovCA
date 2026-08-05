import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplove/app.dart';
import 'package:maplove/routes/app_routes.dart';

void main() {
  testWidgets('all account and member routes use the authentication guard', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const authenticatedRoutes = <String>{
      AppRoutes.deleteAccount,
      AppRoutes.home,
      AppRoutes.discover,
      AppRoutes.nearMe,
      AppRoutes.filters,
      AppRoutes.matches,
      AppRoutes.likes,
      AppRoutes.newMatch,
      AppRoutes.messages,
      AppRoutes.chat,
      AppRoutes.reportUser,
      AppRoutes.blockUser,
      AppRoutes.profile,
      AppRoutes.profileSetup,
      AppRoutes.editProfile,
      AppRoutes.managePhotos,
      AppRoutes.preferences,
      AppRoutes.publicProfile,
      AppRoutes.compatibilityDetails,
      AppRoutes.settings,
      AppRoutes.photoViewer,
      AppRoutes.friendRequests,
      AppRoutes.friends,
      AppRoutes.posts,
      AppRoutes.createPost,
      AppRoutes.postDetails,
      AppRoutes.secretGarden,
      AppRoutes.gardenManagement,
      AppRoutes.gardenAccessRequests,
      AppRoutes.gardenViewer,
      AppRoutes.premium,
      AppRoutes.subscriptionManagement,
      AppRoutes.purchaseStatus,
      AppRoutes.externalCheckoutReturn,
      AppRoutes.notifications,
      AppRoutes.privacy,
      AppRoutes.photoDisplaySettings,
      AppRoutes.security,
      AppRoutes.changeEmail,
      AppRoutes.notificationSettings,
      AppRoutes.language,
      AppRoutes.blockedUsers,
      AppRoutes.helpCenter,
      AppRoutes.legal,
    };

    for (final route in authenticatedRoutes) {
      final widget = AppRouter.routes[route]!(context);
      expect(
        widget.runtimeType.toString(),
        '_AuthenticatedRouteGuard',
        reason: '$route must reject an unauthenticated direct navigation',
      );
    }
  });

  testWidgets('administration routes use the database-role guard', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    const adminRoutes = <String>{
      AppRoutes.adminDashboard,
      AppRoutes.moderationReports,
      AppRoutes.adminUsers,
      AppRoutes.adminAudit,
    };

    for (final route in adminRoutes) {
      final widget = AppRouter.routes[route]!(context);
      expect(
        widget.runtimeType.toString(),
        '_AdminRouteGuard',
        reason: '$route must resolve an authorized database role',
      );
    }
  });
}
