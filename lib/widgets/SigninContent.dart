import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class SigninContent extends StatelessWidget {
  const SigninContent({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    // Firebase authentication instance
    final FirebaseAuth auth = FirebaseAuth.instance;

    Future<void> signIn(BuildContext context) async {
      try {
        final String email = emailController.text.trim();
        final String password = passwordController.text.trim();

        UserCredential userCredential = await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        if (userCredential.user != null) {
          // Go to the map page
          context.go('/map');
        }
      } catch (e) {
        // Handle sign-in errors (e.g., invalid credentials)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password.')),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email Field
          TextField(
            controller: emailController,
            decoration: InputDecoration(
              fillColor: Colors.grey[300],
              filled: true,
              labelText: "Email",
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide.none, // No border
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide.none, // No border
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Password Field
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              fillColor: Colors.grey[300],
              filled: true,
              labelText: "Password",
              labelStyle: const TextStyle(color: Colors.grey),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide.none, // No border
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide.none, // No border
              ),
            ),
          ),
          // Forget Password Text
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // Handle forget password logic
              },
              child: const Text(
                "Forget Password?",
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Sign In Button
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(0),
                ),
              ),
              onPressed: () => signIn(context),
              child: const Text("Sign In", style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
