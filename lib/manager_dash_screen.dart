import 'package:flutter/material.dart';
import 'package:football_mgr/display_match_schedule.dart';
import 'package:football_mgr/playing_XI_management.dart';
import 'package:football_mgr/team_management_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:football_mgr/notification_display_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:football_mgr/profile_screen.dart';
import 'package:football_mgr/login_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  String _managerName = "Manager";


  @override
  void initState() {
    super.initState();
    _loadManagerData();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    
    _controller.forward();
  }

  Future<void> _loadManagerData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.
      collection('users').
      doc(user.uid).
      get();
          
      if (mounted) {
        setState(() {
          _managerName = doc['username'] ?? "Manager";
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade900,
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.logout),
          onPressed: () => _navigateToLogin(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            color: Colors.white,
            onPressed: () => _navigateToNotifications(),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            color: Colors.white,
            onPressed: () => _navigateToProfile(),
          ),
        ],
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: _buildBackgroundDecoration(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
          child: _buildDashboardContent(),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.deepPurpleAccent.shade100,
          Colors.indigoAccent.shade700,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const [0.55, 1.0],
      ),
    );
  }

  Widget _buildDashboardContent() {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildWelcomeSection(),
          _buildAppLogo(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      children: [
        const Text(
          'WELCOME',
          style: TextStyle(
            color: Colors.white,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _managerName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
          ),),
        SizedBox(height: MediaQuery.of(context).size.height * 0.05),
      ],
    );
  }

  Widget _buildAppLogo() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Hero(
        tag: 'app-logo',
        child: Image.asset(
          'assets/images/logo.png',
          height: MediaQuery.of(context).size.height * 0.3,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(Icons.calendar_today, 'Schedule', 0),
          _buildNavButton(Icons.group, 'Team', 1),
          _buildNavButton(Icons.sports, 'XI', 2),
        ],
      ),
    );
  }

  Widget _buildNavButton(IconData icon, String label, int index) {
    return Expanded(
      child: InkWell(
        onTap: () => _handleNavigation(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.bottomToTop,
        child: const ProfileScreen(),
      ),
    );
  }

  void _handleNavigation(int index) {
    final screens = [
      const DisplayScheduleScreen(),
      const MangerTeamManagementScreen(),
      const PlayingXIScreen(),
    ];

    if (index < screens.length) {
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeftWithFade,
          child: screens[index],
        ),
      );
    }
  }

  void _navigateToNotifications() {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.bottomToTop,
        child: DisplayNotificationScreen(userId: currentUser!.uid),
      ),
    );
  }

  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.bottomToTop,
        child: const LoginScreen(),
      ),
    );
  }
}