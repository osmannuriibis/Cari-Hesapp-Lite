//import 'package:eldeki_hesap/views/zzz_deneme/deneme_view.dart';

import 'package:cari_hesapp_lite/views/welcome_screen/auth_wrapper/auth_wrapper_view.dart';
import 'package:cari_hesapp_lite/views/welcome_screen/login_view/login_view.dart';
import 'package:cari_hesapp_lite/views/welcome_screen/sign_up_view/sign_up_view.dart';

import 'package:flutter/cupertino.dart';

// ignore: constant_identifier_names
enum RouteNames { AuthWrapper, Deneme, SignUp, Login }

extension Route on RouteNames {
  String get route {
    switch (this) {
      case RouteNames.AuthWrapper:
        return "/";

      case RouteNames.SignUp:
        return "/signup";

      case RouteNames.Login:
        return "/login";

      case RouteNames.Deneme:
        return "/deneme";

      default:
        throw Exception("There is no View Route: " + toString());
    }
  }

  Widget get view {
    switch (this) {
      case RouteNames.AuthWrapper:
        return const AuthenticationWrapper();

      case RouteNames.SignUp:
        return SignUpView();

      case RouteNames.Login:
        return const LoginView();

      default:
        throw Exception("There is no View Under: " + toString());
    }
  }
}
