import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Screens/AuthPage.dart';
import 'Screens/DashboardPage.dart';
import 'Screens/MapPage.dart';
import 'Screens/RequestPage.dart';
import 'Screens/UserImage.dart';
import 'transitions/SlideTransition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  redirect: (BuildContext context ,GoRouterState state) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && state.location == '/') {
      return '/map';
    }
    if (user == null && (state.location == '/map' || state.location == '/requests' || state.location == '/dashboard')) {
      return '/';
    }
    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AuthPage(),
    ),
    GoRoute(
        path: '/image',
        builder: (context,state) => const UserImage(),
    ),
     GoRoute(
       path: '/map',
       builder: (context, state) {
           final user = FirebaseAuth.instance.currentUser;
           return MapPage(userName: user?.displayName ?? 'Unknown User',userProfileImage: user?.photoURL ?? '',);
         }
     ),
    GoRoute(
        path: '/requests',
        builder: (context,state) => const RequestPage(),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const DashboardPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return slideTransition(animation, secondaryAnimation, child, state);
          },
        );
      },
    ),
  ],
);



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
    );
  }
}

