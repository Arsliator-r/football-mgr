import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:page_transition/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:football_mgr/display_match_schedule.dart';
import 'package:football_mgr/notification_display_screen.dart';
import 'package:football_mgr/player_stats_screen.dart';
import 'package:football_mgr/profile_screen.dart';
import 'package:football_mgr/login_screen.dart';

class PlayerDashboardScreen extends StatefulWidget {
  const PlayerDashboardScreen({super.key});

  @override
  State<PlayerDashboardScreen> createState() => _PlayerDashboardScreenState();
}

class _PlayerDashboardScreenState extends State<PlayerDashboardScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _playerName = "Player";

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
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

  Future<void> _loadPlayerData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
          
      if (mounted) {
        setState(() {
          _playerName = doc['username'] ?? "Player";
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo.shade900,
        leading: IconButton(
          color: Colors.white,
          icon: const Icon(Icons.logout),
          onPressed: () => _navigateToLogin(),
        ),
        actions: [
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.notifications),
            onPressed: () => _navigateToNotifications(context),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            color: Colors.white,
            onPressed: () => _navigateToProfile(),
          ),
        ],
      ),
      extendBody: true,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacityAnimation.value,
          child: child,
        ),
        child: Container(
          height: size.height,
          width: size.width,
          decoration: _backgroundDecoration(),
          child: _buildDashboardContent(size),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  BoxDecoration _backgroundDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.deepPurpleAccent.shade100,
          Colors.indigoAccent.shade700
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const [0.55, 1.0],
      ),
    );
  }

  Widget _buildDashboardContent(Size size) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: size.height * 0.1),
          _buildWelcomeSection(),
          _buildAppLogo(size),
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
          _playerName.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAppLogo(Size size) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Hero(
        tag: 'app-logo',
        child: Image.asset(
          'assets/images/logo.png',
          height: size.height * 0.3,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavButton(Icons.calendar_today, 'Schedule', 0),
          _buildNavButton(Icons.person, 'Stats', 1),
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

  void _handleNavigation(int index) {
    final screens = [
      const DisplayScheduleScreen(),
      const DisplayPlayerStatsScreen(),
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

  void _navigateToNotifications(BuildContext context) {
    Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.bottomToTop,
        child: DisplayNotificationScreen(userId: _auth.currentUser!.uid),
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