import 'package:flutter/material.dart';
import 'package:cloudd_flutter/app_theme.dart';
import 'package:animate_do/animate_do.dart';
import 'login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudd_flutter/models/user.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  final nameController = TextEditingController();
  DateTime? selectedDob;
  File? profileImage;
    bool passwordVisible = false;
  bool confirmPasswordVisible = false;

  @override
  void dispose() {
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  Widget inputContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        profileImage = File(picked.path);
      });
    }
  }

  Future<void> pickDateOfBirth() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(2005),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        selectedDob = date;
      });
    }
  }

  Future<String?> uploadProfileImage(String uid) async {
  if (profileImage == null) return null;

  final ref = FirebaseStorage.instance
      .ref()
      .child('profile_images/$uid.jpg');

  await ref.putFile(profileImage!);
  return await ref.getDownloadURL();
  }


  Future<void> registerUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirm = confirmController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        confirm.isEmpty ||
        name.isEmpty ||
        selectedDob == null) {
      showMessage("Please fill all fields");
      return;
    }

    if (password != confirm) {
      showMessage("Passwords do not match");
      return;
    }

    try {
      // Create user
      // 1️⃣ Create Firebase Auth user
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.sendEmailVerification();

       // 2️⃣ Upload profile image
      final imageUrl = await uploadProfileImage(credential.user!.uid);


      // 3️⃣ Create AppUser MODEL
       final user = AppUser(
        uid: credential.user!.uid,
        email: email,
        name: name,
        role: 'User',
        dateOfBirth: Timestamp.fromDate(selectedDob!),
        profileImageUrl: imageUrl,
      );

      await user.save();

      showMessage("Account created! Please verify your email.");
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-credential':
          errorMessage = "Invalid email or password. Please try again.";
          break;
        case 'email-already-in-use':
          errorMessage = "This email is already registered. Please login instead.";
          break;
        case 'invalid-email':
          errorMessage = "Please enter a valid email address.";
          break;
        case 'weak-password':
          errorMessage = "Password is too weak. Use at least 6 characters.";
          break;
        case 'operation-not-allowed':
          errorMessage = "Email/password sign up is not enabled.";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled.";
          break;
        case 'user-not-found':
          errorMessage = "No account found with this email.";
          break;
        case 'wrong-password':
          errorMessage = "Incorrect password. Please try again.";
          break;
        default:
          errorMessage = e.message ?? "An error occurred. Please try again.";
      }
      showMessage(errorMessage);
    }
  }

  void showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

    // Force light mode styling regardless of the global theme, cause dark mode is not supposed to affect theme of this page
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme.copyWith(
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionColor: Color(0x33000000),
          selectionHandleColor: Colors.black,
        ),
        inputDecorationTheme: AppTheme.lightTheme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey[700]),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.black, width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF8F94FB), width: 2),
          ),
        ),
      ),
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Container(
          child: Column(
            children: <Widget>[
              Container(
                height: 270,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background.png'),
                    fit: BoxFit.fill,
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 30,
                      width: 80,
                      height: 200,
                      child: FadeInUp(
                        duration: Duration(seconds: 1),
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/light-1.png'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 140,
                      width: 80,
                      height: 150,
                      child: FadeInUp(
                        duration: Duration(milliseconds: 1200),
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/light-2.png'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 40,
                      top: 40,
                      width: 80,
                      height: 150,
                      child: FadeInUp(
                        duration: Duration(milliseconds: 1300),
                        child: Container(
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/clock.png'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      child: FadeInUp(
                        duration: Duration(milliseconds: 1600),
                        child: Container(
                          margin: EdgeInsets.only(top: 50),
                          child: Center(
                            child: Text(
                              "ClouDD Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  children: <Widget>[
                    FadeInUp(
                      duration: Duration(milliseconds: 1800),
                      child: Container(
                        padding: EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          // border: Border.all(
                          //   color: Color.fromRGBO(143, 148, 251, 1),
                          // ),
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(143, 148, 251, .2),
                              blurRadius: 20.0,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: <Widget>[

                            // Full Name
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                ),                                
                              ),
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Full Name",
                                ),
                              ),
                            ),

                            // Date of birth
                            Container(
                              
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: GestureDetector(
                                onTap: pickDateOfBirth,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedDob == null
                                          ? "Date of Birth"
                                          : "${selectedDob!.day}/${selectedDob!.month}/${selectedDob!.year}",
                                      style: TextStyle(
                                        color: selectedDob == null ? Colors.grey : Colors.black,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),


                            // Profile Picture
                            GestureDetector(
                              onTap: pickImage,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: CircleAvatar(
                                  radius: 70,
                                  backgroundColor: const Color.fromRGBO(143, 148, 251, 0.4),
                                  backgroundImage:
                                      profileImage != null ? FileImage(profileImage!) : null,
                                  child: profileImage == null
                                      ? const Icon(Icons.camera_alt, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                            // Email
                            Container(
                              padding: EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: emailController,
                                keyboardAppearance: Brightness.light,
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  hintText: "Email",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            ),

                            // Password
                            Container(
                              padding: EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: passwordController,
                                onChanged: (_) => setState(() {}),
                                obscureText: !passwordVisible,
                                keyboardAppearance: Brightness.light,
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  hintText: "Password",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      passwordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey[700],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        passwordVisible = !passwordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),

                            // Confirm Password
                            Container(
                              padding: EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[300]!,
                                    width: 1.0,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: confirmController,
                                onChanged: (_) => setState(() {}),
                                obscureText: !confirmPasswordVisible,
                                keyboardAppearance: Brightness.light,
                                cursorColor: Colors.black,
                                style: TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  filled: false,
                                  hintText: "Confirm Password",
                                  hintStyle: TextStyle(color: Colors.grey[700]),
                                                                    suffixIcon: IconButton(
                                    icon: Icon(
                                      confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey[700],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        confirmPasswordVisible = !confirmPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 5),
                    FadeInUp(
                      duration: Duration(milliseconds: 1850),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 200, top: 10),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Login",
                            style: TextStyle(
                              color: Color.fromRGBO(143, 148, 251, 1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 15),
                    FadeInUp(
                      duration: Duration(milliseconds: 1900),
                      child: GestureDetector(
                        onTap: () {
                          registerUser();
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(143, 148, 251, 1),
                                Color.fromRGBO(143, 148, 251, .6),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Sign Up",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),
                    FadeInUp(
                      duration: Duration(milliseconds: 2000),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 100.0),
                        child: Text(
                          "",
                          style: TextStyle(
                            color: Color.fromRGBO(143, 148, 251, 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
    
  }
}
