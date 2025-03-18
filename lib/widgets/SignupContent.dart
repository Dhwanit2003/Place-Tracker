import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;


class SignUpContent extends StatefulWidget {
  const SignUpContent({super.key});

  @override
  State<SignUpContent> createState() => _SignUpContentState();
}

class _SignUpContentState extends State<SignUpContent> {
  @override
  Widget build(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    Future<String> uploadImageToImgBB(File imageFile) async {
      const String apiKey = '549277580aec8b4590ace6a40dabbf54'; // Replace with your ImgBB API key
      final Uri url = Uri.parse('https://api.imgbb.com/1/upload');

      final img.Image? originalImage = img.decodeImage(imageFile.readAsBytesSync());
      final img.Image resizedImage = img.copyResize(originalImage!, width: 100, height: 100);

      // Save resized image to a temporary file
      final File resizedFile = File(imageFile.path)
        ..writeAsBytesSync(img.encodeJpg(resizedImage, quality: 85));

      final request = http.MultipartRequest('POST', url)
        ..fields['key'] = apiKey
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        final String responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> data = jsonDecode(responseBody);
        return data['data']['url']; // Return the public URL
      } else {
        throw Exception('Failed to upload image');
      }
    }


    Future<void> SignUp(BuildContext context) async {
      try {
        final String name = nameController.text.trim();
        final String email = emailController.text.trim();
        final String password = passwordController.text;

        final String? imagePath = await context.push<String>('/image');

        final File imageFile = File(imagePath!);
        final String imageUrl = await uploadImageToImgBB(imageFile);

        final UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        final User? user = userCredential.user;

        await user?.updateDisplayName(name);
        await user?.updatePhotoURL(imageUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign Up Successful!')),
        );

        context.go('/map');
      }

      catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already Signed Up')),
        );
        print("Error $e");
      }
    }


    return Builder(
        builder: (BuildContext context) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    fillColor: Colors.grey[300],
                    filled: true,
                    labelText: "Name",
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide.none, // No border
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide.none, // No border
                    ),
                  ),
                ),
                SizedBox(height: 10,),
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
                const SizedBox(height: 10),
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
                    onPressed: () => SignUp(context),
                    child: const Text(
                        "Sign Up", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          );
        }
    );
  }
}
