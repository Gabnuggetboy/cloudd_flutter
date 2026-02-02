import 'package:flutter/material.dart';
import 'package:cloudd_flutter/app_theme.dart';
import 'package:animate_do/animate_do.dart';
import 'signup_page.dart';
import 'user/home_page.dart';
import 'manager/manager_account_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:cloudd_flutter/theme_provider.dart';
import 'package:cloudd_flutter/forgot_password_page.dart';
// import 'package:cloudd_flutter/webapp_access_page.dart';
// import 'icube_test.dart';
import 'package:cloudd_flutter/models/user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  bool get _isFormFilled =>
      _emailController.text.isNotEmpty && _passwordController.text.isNotEmpty;

  Future<void> loginUser() async {
    if (_isLoading) return; // Prevent multiple calls

    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showErrorDialog("Please fill all fields");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Log in the user
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;

      if (user == null) {
        showErrorDialog("Unexpected error. Try again.");
        return;
      }

      // Check if email is verified
      if (!user.emailVerified) {
        showErrorDialog("Please verify your email before logging in.");
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Get user role from Firestore
      DocumentSnapshot snap = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final appUser = AppUser.fromDoc(snap);

      // Refresh theme preference for the logged-in user
      if (!mounted) return;
      await Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).refreshThemePreference();

      if (!mounted) return;
      // Redirect based on role
      if (appUser.isManager) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ManagerAccountPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-credential':
          errorMessage = "Invalid email or password. Please try again.";
          break;
        case 'invalid-email':
          errorMessage = "Please enter a valid email address.";
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
        case 'too-many-requests':
          errorMessage = "Too many failed attempts. Please try again later.";
          break;
        default:
          errorMessage = e.message ?? "Login failed. Please try again.";
      }
      showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // user MUST press OK
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Login Error"),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
/*
Sdsda
*/
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
          physics: NeverScrollableScrollPhysics(),
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
                        right: 12,
                        top: 12,
                        child: FadeInUp(
                          duration: Duration(milliseconds: 1100),
                          child: Row(
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 217),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ManagerAccountPage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Manager',
                                  style: TextStyle(
                                    color: Color.fromRGBO(143, 148, 251, 1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              TextButton(
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 217),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const HomePage(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'User',
                                  style: TextStyle(
                                    color: Color.fromRGBO(143, 148, 251, 1),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              // TextButton(
                              //   style: TextButton.styleFrom(
                              //     backgroundColor: Colors.white.withOpacity(0.85),
                              //     padding: EdgeInsets.symmetric(
                              //       horizontal: 12,
                              //       vertical: 8,
                              //     ),
                              //   ),
                              //   onPressed: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (context) =>
                              //             const StoryTimeWebappPage(),
                              //       ),
                              //     );
                              //   },
                              //   child: Text(
                              //     'Web App Access',
                              //     style: TextStyle(
                              //       color: Color.fromRGBO(143, 148, 251, 1),
                              //       fontWeight: FontWeight.w600,
                              //     ),
                              //   ),
                              // ),
                              // SizedBox(width: 8),
                              // TextButton(
                              //   style: TextButton.styleFrom(
                              //     backgroundColor: Colors.white.withOpacity(0.85),
                              //     padding: EdgeInsets.symmetric(
                              //       horizontal: 12,
                              //       vertical: 8,
                              //     ),
                              //   ),
                              //   onPressed: () {
                              //     Navigator.push(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (context) => const IrigTestPage(),
                              //       ),
                              //     );
                              //   },
                              //   child: Text(
                              //     'irig test',
                              //     style: TextStyle(
                              //       color: Color.fromRGBO(143, 148, 251, 1),
                              //       fontWeight: FontWeight.w600,
                              //     ),
                              //   ),
                              // ),
                              SizedBox(width: 8),
                              // TextButton(
                              // style: TextButton.styleFrom(
                              //   backgroundColor: Colors.white.withOpacity(0.85),
                              //   padding: EdgeInsets.symmetric(
                              //     horizontal: 12,
                              //     vertical: 8,
                              //   ),
                              // ),
                              // onPressed: () {
                              // Navigator.push(
                              //   context,
                              //   MaterialPageRoute(
                              //     builder: (context) => const iCubeTestPage(),
                              //   ),
                              // );
                              // },
                              // child: Text(
                              //   'iCube test',
                              //   style: TextStyle(
                              //     color: Color.fromRGBO(143, 148, 251, 1),
                              //     fontWeight: FontWeight.w600,
                              //   ),
                              // ),
                              // ),
                            ],
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
                                "ClouDD Login",
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
                            border: Border.all(
                              color: Color.fromRGBO(143, 148, 251, 1),
                            ),
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
                              Container(
                                padding: EdgeInsets.all(8.0),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color.fromRGBO(143, 148, 251, 1),
                                    ),
                                  ),
                                ),
                                child: TextField(
                                  controller: _emailController,
                                  onChanged: (_) => setState(() {}),
                                  keyboardAppearance: Brightness.light,
                                  cursorColor: Colors.black,
                                  style: TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    filled: false,
                                    hintText: "Email",
                                    hintStyle: TextStyle(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _passwordController,
                                  onChanged: (_) => setState(() {}),
                                  obscureText: !_passwordVisible, // Use a state variable to control visibility
                                  keyboardAppearance: Brightness.light,
                                  cursorColor: Colors.black,
                                  style: TextStyle(color: Colors.black),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    filled: false,
                                    hintText: "Password",
                                    hintStyle: TextStyle(
                                      color: Colors.grey[700],
                                    ),

                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey[700],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
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
                                  builder: (context) => SignUpPage(),
                                ),
                              );
                            },
                            child: Text(
                              "Sign Up",
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
                        child: IgnorePointer(
                          ignoring: _isLoading || !_isFormFilled,
                          child: Opacity(
                            opacity: _isLoading ? 0.6 : 1.0,
                            child: GestureDetector(
                              onTap: () {
                                loginUser();
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: (_isFormFilled && !_isLoading)
                                        ? [
                                            const Color(0xFF5B60C8),
                                            const Color(0xFF3F438F),
                                          ]
                                        : [
                                            const Color.fromRGBO(
                                              143,
                                              148,
                                              251,
                                              1,
                                            ),
                                            const Color.fromRGBO(
                                              143,
                                              148,
                                              251,
                                              .6,
                                            ),
                                          ],
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "Login",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                           child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordPage(),
                              ),
                            );
                          },
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(
                              color: Color.fromRGBO(143, 148, 251, 1),
                              fontWeight: FontWeight.w600
                            ),
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
    );
  }
}
