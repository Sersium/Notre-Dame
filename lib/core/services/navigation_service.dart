// Flutter imports:
import 'package:flutter/material.dart';

// Project imports:
import 'package:notredame/core/constants/router_paths.dart';
import 'package:notredame/core/services/remote_config_service.dart';
import 'package:notredame/locator.dart';

//SERVICE

//CONSTANT

//OTHERS

/// Navigation service who doesn't use the BuildContext which allow us to call it from anywhere.
class NavigationService {
  final RemoteConfigService remoteConfigService =
      locator<RemoteConfigService>();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  /// Pop the last route of the navigator if possible
  bool pop() {
    if (_navigatorKey.currentState.canPop()) {
      _navigatorKey.currentState.pop();
      return true;
    }
    return false;
  }

  /// Push a named route ([routeName] onto the navigator.
  Future<dynamic> pushNamed(String routeName, {dynamic arguments}) {
    if (remoteConfigService.outage) {
      return _navigatorKey.currentState
          .pushNamedAndRemoveUntil(RouterPaths.serviceOutage, (route) => false);
    }
    return _navigatorKey.currentState
        .pushNamed(routeName, arguments: arguments);
  }

  /// Replace the current route of the navigator by pushing the route named
  /// [routeName] and then delete the stack of previous routes
  Future<dynamic> pushNamedAndRemoveUntil(String routeName,
      [String removeUntilRouteNamed = RouterPaths.dashboard,
      Object arguments]) {
    if (remoteConfigService.outage) {
      return _navigatorKey.currentState
          .pushNamedAndRemoveUntil(RouterPaths.serviceOutage, (route) => false);
    }
    return _navigatorKey.currentState.pushNamedAndRemoveUntil(
        routeName, ModalRoute.withName(removeUntilRouteNamed),
        arguments: arguments);
  }
}
