import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayPlayerStatsScreen extends StatefulWidget {
  const DisplayPlayerStatsScreen({super.key});

  @override
  State<DisplayPlayerStatsScreen> createState() => _DisplayPlayerStatsScreenState();
}

class _DisplayPlayerStatsScreenState extends State<DisplayPlayerStatsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _playerData;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlayerData();
  }

  Future<void> _loadPlayerData() async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) {
        _updateErrorState('User not authenticated');
        return;
      }

      final playerDoc = await _findPlayerDocument(user.email!);
      if (playerDoc == null) {
        _updateErrorState('Player profile not found');
        return;
      }

      if (mounted) {
        setState(() {
          _playerData = playerDoc.data() as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      _updateErrorState('Error loading data: ${e.toString()}');
    }
  }

  Future<DocumentSnapshot?> _findPlayerDocument(String email) async {
    final query = await _firestore.collectionGroup('players')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    return query.docs.isNotEmpty ? query.docs.first : null;
  }

  void _updateErrorState(String message) {
    if (mounted) {
      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox.expand(
            child: Container(
              decoration: _backgroundDecoration(),
              child: _buildContent(),
            ),
          );
        },
      ),
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

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _ErrorDisplay(
        message: _errorMessage!,
        onRetry: _loadPlayerData,
      );
    }

    return _PlayerStatsContent(playerData: _playerData!);
  }
}

class _PlayerStatsContent extends StatelessWidget {
  final Map<String, dynamic> playerData;

  const _PlayerStatsContent({required this.playerData});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          const _ScreenTitle(),
          const Divider(color: Colors.white54, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _StatsCard(
              playerName: playerData['name'] ?? 'Player Name',
              position: playerData['position'] ?? 'Position',
              height: playerData['height_cm'].toString() + ' cm',
              preferredFoot: playerData['preferred_foot'] ?? 'Foot',

              skills: _extractSkills(playerData),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _extractSkills(Map<String, dynamic> data) {
    const skillKeys = [
      'defending', 'dribbling', 'pace', 
      'passing', 'shooting', 'physicality'
    ];
    
    return Map.fromEntries(
      skillKeys.map((key) => MapEntry(
        key,
        (data[key] as num?)?.toDouble() ?? 0.0
      ))
    );
  }
}

class _ScreenTitle extends StatelessWidget {
  const _ScreenTitle();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'PLAYER STATISTICS',
      style: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String playerName;
  final String position;
  final String height;
  final String preferredFoot;

  final Map<String, double> skills;

  const _StatsCard({
    required this.playerName,
    required this.position,
    required this.height,
    required this.preferredFoot,
    required this.skills,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _PlayerHeader(name: playerName, position: position, 
            height: height, preferredFoot: preferredFoot),
          const SizedBox(height: 24),
          _SkillsList(skills: skills),
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final String name;
  final String position;
  final String height;
  final String preferredFoot;

  const _PlayerHeader({
    required this.name,
    required this.position,
    required this.height,
    required this.preferredFoot,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.indigoAccent.shade700,
          child: const Icon(
            Icons.person_outline,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: $name',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Position: $position',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Height: $height',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Preferred Foot: $preferredFoot',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkillsList extends StatelessWidget {
  final Map<String, double> skills;

  const _SkillsList({required this.skills});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: skills.entries.map((entry) => 
        _SkillProgress(
          skillName: entry.key,
          value: entry.value,
        )
      ).toList(),
    );
  }
}

class _SkillProgress extends StatelessWidget {
  final String skillName;
  final double value;

  const _SkillProgress({
    required this.skillName,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatSkillName(skillName),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              Text(
                '${value.toInt()}%',
                style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: Colors.deepPurpleAccent.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.indigoAccent.shade700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSkillName(String name) {
    return name[0].toUpperCase() + name.substring(1);
  }
}

class _ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorDisplay({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 20),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}