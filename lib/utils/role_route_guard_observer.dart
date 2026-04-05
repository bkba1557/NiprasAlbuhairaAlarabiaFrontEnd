import 'package:flutter/material.dart';
import 'package:order_tracker/providers/auth_provider.dart';
import 'package:order_tracker/utils/app_routes.dart';
import 'package:order_tracker/utils/role_route_policy.dart';
import 'package:provider/provider.dart';

class RoleRouteGuardObserver extends NavigatorObserver {
  bool _redirectInProgress = false;

  void _enforce(Route<dynamic>? route) {
    if (_redirectInProgress) return;

    final nav = navigator;
    if (nav == null || route == null) return;

    final routeName = route.settings.name;
    if (routeName == null || routeName.trim().isEmpty) return;

    final auth = Provider.of<AuthProvider>(nav.context, listen: false);
    if (!auth.isAuthenticated || auth.user == null) return;

    final role = auth.user?.role;
    if (isRouteAllowedForRole(role: role, routeName: routeName)) return;

    final redirectRoute = restrictedRoleHomeRoute(role);
    if (redirectRoute == null) return;

    _redirectInProgress = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav2 = navigator;
      if (nav2 == null) {
        _redirectInProgress = false;
        return;
      }

      nav2.pushNamedAndRemoveUntil(
        redirectRoute,
        (route) => false,
      );
      _redirectInProgress = false;
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _enforce(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _enforce(newRoute);
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _enforce(previousRoute);
    super.didPop(route, previousRoute);
  }
}
