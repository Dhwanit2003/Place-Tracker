import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../transitions/SlidingContent.dart';
import '../widgets/SigninContent.dart';
import '../widgets/SignupContent.dart';
import 'package:http/http.dart' as http;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool showLogin = true;

  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      context.go('/map');
      return userCredential.user;
    } catch (e) {
      print("Error signing in with Google: $e");
      return null;
    }
  }

  Future<User?> signInWithGitHub(BuildContext context) async {
    try {
      // Replace with your GitHub app details
      const clientId = 'Ov23li91FBtLwN5nWqhS';
      const clientSecret = '78070f215cc642bc57a91b28600109bebcb402e7';
      const redirectUri = 'https://tracker-app-56-6e384.firebaseapp.com/__/auth/handler';
      const authorizationEndpoint = 'https://github.com/login/oauth/authorize';
      const tokenEndpoint = 'https://github.com/login/oauth/access_token';

      // Step 1: Initiate GitHub login via browser
      final authUrl = '$authorizationEndpoint?client_id=$clientId&redirect_uri=$redirectUri&scope=read:user,user:email';
      final result = await FlutterWebAuth.authenticate(
          url: authUrl, callbackUrlScheme: "https");

      // Step 2: Extract authorization code
      final code = Uri.parse(result).queryParameters['code'];

      // Step 3: Exchange the authorization code for an access token
      final response = await http.post(
        Uri.parse(tokenEndpoint),
        headers: {'Accept': 'application/json'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri,
        },
      );

      final tokenResponse = json.decode(response.body);
      final accessToken = tokenResponse['access_token'];

      // Step 4: Use the access token to sign in with Firebase
      final credential = GithubAuthProvider.credential(accessToken);
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

      // Navigate to the map page on success
      context.go('/map');
      return userCredential.user;
    } catch (e) {
      print("Error signing in with GitHub: $e");
      return null;
    }
  }



  Future<User?> signInWithFacebook(BuildContext context) async {
    try {
      final LoginResult result = await FacebookAuth.i.login();

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final credential = FacebookAuthProvider.credential(accessToken.token);

        final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
        context.go('/map');
        return userCredential.user;
      } else if (result.status == LoginStatus.cancelled) {
        print("Facebook login cancelled");
        return null;
      } else {
        print("Facebook login failed: ${result.message}");
        return null;
      }
    } catch (e) {
      print("Error signing in with Facebook: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded, color: Colors.white, size: 35),
                SizedBox(width: 8),
                Text(
                  'Place Tracker App',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Container(
          decoration: BoxDecoration(
          image: DecorationImage(
          image: AssetImage('assets/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            height: 565,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                color: Colors.white,
                elevation: 20,
                shadowColor: Colors.black,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => showLogin = true),
                            child: Container(
                              height: 60, // Adjust height if needed
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: showLogin ? Colors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(8), // Set the radius of the corners
                              ),
                              child: Text(
                                "Sign In",
                                style: TextStyle(fontSize: 18,
                                    color: showLogin ? Colors.white : Colors.black),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => showLogin = false),
                            child: Container(
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: !showLogin ? Colors.green : Colors.transparent,
                                borderRadius: BorderRadius.circular(8), // Set the radius of the corners
                              ),
                              child: Text(
                                "Sign Up",
                                style: TextStyle(fontSize: 18,
                                    color: !showLogin ? Colors.white : Colors.black),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SlidingContent(
                      key: ValueKey(showLogin),
                      showContent: showLogin,
                      child: showLogin
                          ? const SigninContent()
                          : const SignUpContent(),
                    ),
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(160, 60), // Half-width buttons
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () async {
                                  User? user = await signInWithGoogle(context);
                                  if (user != null) {
                                    print("Signed in as: ${user.displayName}");
                                  } else {
                                    print("Sign-in failed");
                                  }
                                },
                                child: const Text(
                                  "Google",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(160, 60),
                                  backgroundColor: Colors.blue,
                                ),
                                onPressed: () async {
                                  User? user = await signInWithFacebook(context);
                                  if (user != null) {
                                    print("Signed in with Facebook: ${user.displayName}");
                                  } else {
                                    print("Facebook sign-in failed");
                                  }
                                },
                                child: const Text(
                                  "Facebook",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(160, 60),
                                  backgroundColor: Colors.black,
                                ),
                                onPressed: () async {
                                  User? user = await signInWithGitHub(context);
                                  if (user != null) {
                                    print("Signed in with GitHub: ${user.displayName}");
                                  } else {
                                    print("GitHub sign-in failed");
                                  }
                                },
                                child: const Text(
                                  "Github",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(160, 60),
                                  backgroundColor: Colors.black,
                                ),  
                                onPressed: (){},
                                child: const Text(
                                  "Twitter Login",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

