import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../themes/colors.dart';
import '../../services/analytics_service.dart';
import '../homepage.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isPasswordFocused = false;
  late FocusNode _passwordFocusNode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _passwordFocusNode = FocusNode();
    _passwordFocusNode.addListener(() {
      setState(() {
        _isPasswordFocused = _passwordFocusNode.hasFocus;
      });
    });
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Create user with Firebase Auth
      final UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update user profile with username
      if (userCredential.user != null && username.isNotEmpty) {
        try {
          await userCredential.user!.updateDisplayName(username);
          await userCredential.user!.reload();
        } catch (e) {
          // Log error but don't fail the signup if display name update fails
          debugPrint('Failed to update display name: $e');
        }
      }

      // Send email verification
      if (userCredential.user != null) {
        try {
          await userCredential.user!.sendEmailVerification();
        } catch (e) {
          // Log error but don't fail the signup if email verification fails
          debugPrint('Failed to send email verification: $e');
        }
      }

      if (userCredential.user != null && mounted) {
        // Track signup event
        await AnalyticsService.logEvent(
          name: 'sign_up',
          parameters: {'method': 'email'},
        );
        await AnalyticsService.setUserId(userCredential.user!.uid);
        await AnalyticsService.setUserIdentifier(userCredential.user!.uid);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Account created successfully! Please verify your email and sign in.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to login page
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      // Log error to Crashlytics
      await AnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Signup failed: ${e.code}',
        fatal: false,
      );

      String errorMessage = 'An error occurred. Please try again.';

      if (e.code == 'weak-password') {
        errorMessage = 'Your password is too weak. Please use a stronger password.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage =
        'An account with this email already exists. Please sign in instead.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.code == 'operation-not-allowed') {
        errorMessage =
        'Email/password sign up is currently disabled. Please contact support.';
      } else if (e.code == 'network-request-failed') {
        errorMessage =
        'Unable to connect. Please check your internet connection and try again.';
      } else {
        // Show user-friendly message instead of technical error
        errorMessage =
        'Unable to create account. Please check your information and try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Log unexpected errors to Crashlytics
      await AnalyticsService.recordError(
        e,
        stackTrace,
        reason: 'Unexpected signup error',
        fatal: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      // Trigger the Google Sign In flow
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleAccount =
      await googleSignIn.signIn();

      if (googleAccount == null) {
        // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
      await googleAccount.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);

      // Update display name if not set (for new users)
      if (userCredential.user != null &&
          userCredential.user!.displayName == null &&
          googleAccount.displayName != null) {
        try {
          await userCredential.user!
              .updateDisplayName(googleAccount.displayName);
          await userCredential.user!.reload();
        } catch (e) {
          debugPrint('Failed to update display name from Google: $e');
        }
      }

      if (userCredential.user != null && mounted) {
        // Track Google signup/signin event
        final isNewUser =
            userCredential.additionalUserInfo?.isNewUser ?? false;
        await AnalyticsService.logEvent(
          name: isNewUser ? 'sign_up' : 'login',
          parameters: {'method': 'google'},
        );
        await AnalyticsService.setUserId(userCredential.user!.uid);
        await AnalyticsService.setUserIdentifier(userCredential.user!.uid);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Google sign in failed: ${e.message ?? e.code}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleAppleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (credential.identityToken != null) {
        // Create an OAuth credential for Firebase
        final oauthCredential = OAuthProvider("apple.com").credential(
          idToken: credential.identityToken,
          accessToken: credential.authorizationCode,
        );

        // Sign in to Firebase with the Apple credential
        final UserCredential userCredential =
        await FirebaseAuth.instance
            .signInWithCredential(oauthCredential);

        // Update display name if available (only on first sign in)
        if (userCredential.user != null &&
            userCredential.user!.displayName == null &&
            credential.givenName != null) {
          try {
            final fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();
            if (fullName.isNotEmpty) {
              await userCredential.user!.updateDisplayName(fullName);
              await userCredential.user!.reload();
            }
          } catch (e) {
            debugPrint('Failed to update display name from Apple: $e');
          }
        }

        if (userCredential.user != null && mounted) {
          // Track Apple signup/signin event
          final isNewUser =
              userCredential.additionalUserInfo?.isNewUser ?? false;
          await AnalyticsService.logEvent(
            name: isNewUser ? 'sign_up' : 'login',
            parameters: {'method': 'apple'},
          );
          await AnalyticsService.setUserId(userCredential.user!.uid);
          await AnalyticsService.setUserIdentifier(
              userCredential.user!.uid);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Signed in with Apple successfully!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
              const HomePage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 400),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple sign in failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24.0,
                    right: 24.0,
                    top: 24.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 60.0,
                  ),
                  keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          MediaQuery.of(context).viewInsets.bottom -
                          48.0,
                    ),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Back button
                            Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Logo/Icon
                            Container(
                              height: 100,
                              width: 100,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_add,
                                size: 50,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Title
                            Text(
                              'Create Account 🎉',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start your note-taking journey today',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Username field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _usernameController,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: 'Username',
                                  prefixIcon: const Icon(
                                    Icons.person_outline,
                                    color: AppColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (value.length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  if (value.length > 20) {
                                    return 'Username must be less than 20 characters';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Email field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  hintText: 'Email',
                                  prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    color: AppColors.primary,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Password field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: _obscurePassword,
                                onChanged: (value) {
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  hintText: 'Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() =>
                                      _obscurePassword = !_obscurePassword);
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (value.length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  // Check for at least one letter
                                  if (!value.contains(RegExp(r'[a-zA-Z]'))) {
                                    return 'Password must contain at least one letter';
                                  }
                                  // Check for at least one number
                                  if (!value.contains(RegExp(r'[0-9]'))) {
                                    return 'Password must contain at least one number';
                                  }
                                  return null;
                                },
                              ),
                            ),

                            // Password requirements hint (shown when focused or has text)
                            if (_isPasswordFocused ||
                                _passwordController.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left: 4.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '8+ characters with letters & numbers',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (_isPasswordFocused ||
                                _passwordController.text.isNotEmpty)
                              const SizedBox(height: 12),
                            if (!_isPasswordFocused &&
                                _passwordController.text.isEmpty)
                              const SizedBox(height: 20),

                            // Confirm Password field
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  hintText: 'Confirm Password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    color: AppColors.primary,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: AppColors.textSecondary,
                                    ),
                                    onPressed: () {
                                      setState(() => _obscureConfirmPassword =
                                      !_obscureConfirmPassword);
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'The passwords you entered do not match. Please check and try again.';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Sign Up button
                            Container(
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark
                                        .withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed:
                                _isLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                                    : Text(
                                  'Sign Up',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.8),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    color: Colors.white.withOpacity(0.3),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            // Google Sign In
                            _SocialButton(
                              icon: Icons.g_mobiledata,
                              label: 'Continue with Google',
                              onPressed:
                              _isLoading ? null : _handleGoogleSignIn,
                              color: Colors.white,
                              textColor: AppColors.textPrimary,
                            ),
                            const SizedBox(height: 16),

                            // Apple Sign In
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS &&
                                !_isLoading)
                              SignInWithAppleButton(
                                onPressed: () => _handleAppleSignIn(),
                                height: 56,
                                borderRadius: BorderRadius.circular(16),
                                text: 'Continue with Apple',
                              ),
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS &&
                                _isLoading)
                              Container(
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 30),

                            // Login link
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      'Sign In',
                                      style: GoogleFonts.poppins(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
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
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;

  const _SocialButton({
    required this.icon,
    required this.label,
    this.onPressed,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 28),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
