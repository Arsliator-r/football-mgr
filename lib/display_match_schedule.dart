import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayScheduleScreen extends StatefulWidget {
  const DisplayScheduleScreen({super.key});

  @override
  State<DisplayScheduleScreen> createState() => _DisplayScheduleScreenState();
}

class _DisplayScheduleScreenState extends State<DisplayScheduleScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: MediaQuery.of(context).size.width,
      decoration: _backgroundDecoration(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _opacityAnimation.value,
          child: child,
        ),
        child: _buildContent(),
      ),
    );
  }

  BoxDecoration _backgroundDecoration() {
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

  Widget _buildContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildFixtureList(),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20),
      child: Column(
        children: [
          const Text(
            'MATCH DETAILS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white54),
          _buildSectionTitle('Fixtures'),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFixtureList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('fixtures')
            .orderBy('date')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator();
          }

          if (snapshot.hasError) {
            return _buildErrorDisplay(snapshot.error.toString());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return _buildFixtureItems(snapshot.data!.docs);
        },
      ),
    );
  }

  Widget _buildFixtureItems(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final fixture = docs[index];
        return _FixtureItem(
          fixture: fixture,
          animation: CurvedAnimation(
            parent: _controller,
            curve: Interval(index * 0.1, 1.0, curve: Curves.easeOut),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Text(
        'No fixtures scheduled',
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildErrorDisplay(String error) {
    return Center(
      child: Text(
        'Error: $error',
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

class _FixtureItem extends StatelessWidget {
  final QueryDocumentSnapshot fixture;
  final Animation<double> animation;

  const _FixtureItem({
    required this.fixture,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final data = fixture.data() as Map<String, dynamic>;
    
    return SizeTransition(
      sizeFactor: animation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTeamRow(
              data['team1Ref'] as DocumentReference,
              data['team2Ref'] as DocumentReference,
            ),
            const SizedBox(height: 12),
            _buildVenueRow(Icons.location_on, data['venueRef'] as DocumentReference),
            _buildDetailRow(Icons.access_time, '${data['date']} ${data['time']}'),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamRow(DocumentReference team1Ref, DocumentReference team2Ref) {
    return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      Expanded(
        child: FutureBuilder<DocumentSnapshot>(
          future: team1Ref.get(),
          builder: (context, snapshot) {
            // Handle loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.indigo,
              );
            }

            // Handle errors
            if (snapshot.hasError) {
              return const Text(
                'Error',
                style: TextStyle(color: Colors.red),
              );
            }

            // Handle missing document
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text(
                'Unknown Team',
                style: TextStyle(fontStyle: FontStyle.italic),
              );
            }

            // Get data with null safety
            final teamData = snapshot.data!.data() as Map<String, dynamic>?;
            final teamName = teamData?['club_name'] ?? 'Unnamed Team';

            return Text(
              teamName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            );
          },
        ),
      ), 
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'VS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<DocumentSnapshot>(
            future: team2Ref.get(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('Error');
              if (!snapshot.hasData) return const CircularProgressIndicator();
              
              final teamName = snapshot.data != null && snapshot.data!.exists
                  ? (snapshot.data!.data() as Map<String, dynamic>).containsKey('club_name')
                      ? snapshot.data!.get('club_name')
                      : 'Unnamed Team'
                  : 'Team Not Found';
              return Text(
                teamName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVenueRow(IconData icon, DocumentReference venueRef) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.indigo.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: FutureBuilder<DocumentSnapshot>(
            future: venueRef.get(),
            builder: (context, snapshot) {
              // Handle loading state
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo),
                  ),
                );
              }

              // Handle error state
              if (snapshot.hasError) {
                return Text(
                  'Error loading venue',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 14,
                  ),
                );
              }

              // Handle missing document
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Text(
                  'Unknown venue',
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 14,
                  ),
                );
              }

              // Get venue name from document
              final venueName = snapshot.data!.get('name') ?? 'Unknown venue';

              return Text(
                venueName,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.indigo.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}