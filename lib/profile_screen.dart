import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:page_transition/page_transition.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;
  final _passwordFormKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  String? name;
  String? email;
  bool _isUpdatingPassword = false;

  // Add controllers for password fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn),
    );
    
    _controller.forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildProfileInfoCard(String label, String? value) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, 
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(value ?? 'Loading...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _editPassword(BuildContext context) {
    showGeneralDialog(
      context: context,
      pageBuilder: (_, __, ___) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.indigo.shade900,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _passwordFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Change Password', 
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    controller: _currentPasswordController,
                    label: 'Current Password',
                    enabled: !_isUpdatingPassword,
                  ),
                  const SizedBox(height: 15),
                  _buildPasswordField(
                    controller: _newPasswordController,
                    label: 'New Password',
                    enabled: !_isUpdatingPassword,
                  ),
                  const SizedBox(height: 15),
                  _buildPasswordField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    enabled: !_isUpdatingPassword,
                  ),
                  const SizedBox(height: 25),
                  _isUpdatingPassword
                      ? const CircularProgressIndicator()
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', 
                                style: TextStyle(color: Colors.white70)),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _handlePasswordUpdate,
                              child: const Text('Update Password'),
                            ),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: anim,
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      enabled: enabled,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white54),
          borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.indigoAccent),
          borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Required field';
        if (label == 'New Password' && value.length < 6) 
          return 'Minimum 6 characters';
        return null;
      },
    );
  }

  Future<void> _handlePasswordUpdate() async {
  if (!_passwordFormKey.currentState!.validate()) return;
  if (_newPasswordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New passwords do not match!')),
    );
    return;
  }

  setState(() => _isUpdatingPassword = true);
  
  try {
    final user = FirebaseAuth.instance.currentUser;
    final cred = EmailAuthProvider.credential(
      email: user!.email!,
      password: _currentPasswordController.text,
    );

    // Reauthenticate user
    await user.reauthenticateWithCredential(cred);
    
    // Update password
    await user.updatePassword(_newPasswordController.text);
    
    // Clear fields and close dialog
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // <-- Key fix here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully!')),
      );
    }
  } on FirebaseAuthException catch (e) {
    String message = 'Password update failed';
    if (e.code == 'wrong-password') {
      message = 'Incorrect current password';
    } else if (e.code == 'weak-password') {
      message = 'New password is too weak';
    } else if (e.code == 'requires-recent-login') {
      message = 'Please re-login and try again';
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  } finally {
    if (mounted) setState(() => _isUpdatingPassword = false);
  }
}

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: _slideAnimation.value * 50,
            child: child,
          ),
        ),
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurpleAccent.shade100,
                Colors.indigoAccent.shade700,
              ],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'profile-logo',
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: size.width * 0.5,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => 
                        const Icon(Icons.person, size: 100, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildProfileInfoCard('DISPLAY NAME', name),
                  _buildProfileInfoCard('EMAIL ADDRESS', email),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isUpdatingPassword
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Change Password'),
                            onPressed: () => _editPassword(context),
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.indigoAccent.withOpacity(0.8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            ),
                          ),),
                  const SizedBox(height: 40),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        email = user.email;
      });

      // Assuming all users are stored in the "users" collection using their UID
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          name = doc.data()?['username'] ?? 'No Name Found';
        });
      }
    }
  }

}
