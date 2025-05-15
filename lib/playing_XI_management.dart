import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlayingXIScreen extends StatefulWidget {
  const PlayingXIScreen({super.key});

  @override
  State<PlayingXIScreen> createState() => _PlayingXIScreenState();
}

class _PlayingXIScreenState extends State<PlayingXIScreen> {
  bool _isValidating = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _clubId;
  final _formationPositions = [
    'Goal Keeper', 'Left Back', 'Center Back 1', 'Center Back 2', 'Right Back',
    'Left Midfielder', 'Central Midfielder', 'Right Midfielder', 'Left Winger',
    'Striker', 'Right Winger'
  ];

  @override
  void initState() {
    super.initState();
    _loadClubId();
  }

  Future<void> _loadClubId() async {
    final snapshot = await _firestore.collection('clubs')
        .where('manager_id', isEqualTo: _auth.currentUser!.uid)
        .limit(1)
        .get();
    
    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() => _clubId = snapshot.docs.first.id);
      await _initializePlayingXIDocuments();
      await _validateSlotsOnLoad(); 
    }
  }

  Future<void> _initializePlayingXIDocuments() async {
    final xiRef = _firestore.collection('clubs').doc(_clubId).collection('Playing_XI');
    
    for (int i = 0; i < _formationPositions.length; i++) {
      final docId = 'position_${i + 1}';
      final doc = await xiRef.doc(docId).get();
      
      if (!doc.exists) {
        await xiRef.doc(docId).set({
          'position': _formationPositions[i],
          'empty': true,
          'player_uid': null,
          'timestamp': FieldValue.serverTimestamp()
        });
      } else if (!doc.data()!.containsKey('player_uid')) {
      // Update existing docs missing player_uid
      await xiRef.doc(docId).update({'player_uid': null});
    }
    }
}

Future<void> _validateSlotsOnLoad() async {
  if (_clubId == null) return;

  final xiRef = _firestore.collection('clubs').doc(_clubId!).collection('Playing_XI');
  final slotsSnapshot = await xiRef.get();

  for (final slotDoc in slotsSnapshot.docs) {
    final slotData = slotDoc.data();
    final playerUid = slotData['player_uid'] as String?;
    final slotPosition = slotData['position'] as String?;

    if (playerUid == null || slotPosition == null) continue;

    try {
      final playerDoc = await _firestore.collection('clubs')
          .doc(_clubId)
          .collection('players')
          .doc(playerUid)
          .get();

      final playerPosition = playerDoc.get('position') as String?;

      // Clear slot if position mismatch or player no longer exists
      if (!playerDoc.exists || playerPosition != slotPosition) {
        await xiRef.doc(slotDoc.id).update({
          'player_uid': null,
          'empty': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error validating slot ${slotDoc.id}: $e');
    }
  }
}

  Widget _buildFormationGrid(List<QueryDocumentSnapshot> slots) {

    final slotMap = {for (var doc in slots) doc.id: doc};

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10
      ),
      itemCount: _formationPositions.length,
      itemBuilder: (context, index) {
        final expectedDocId = 'position_${index + 1}';
      final slot = slotMap[expectedDocId];
      final playerData = slot?.data() as Map<String, dynamic>? ?? {'empty': true};
        
      final isEmpty = (playerData['player_uid'] == null) || 
                     (playerData['empty'] == true);

        return _PositionCard(
          position: _formationPositions[index],
          player: isEmpty ? null : playerData,
          onTap: () => _showReplacementDialog(
          expectedDocId,
          _formationPositions[index],
          ),);
      },
    );
}

void _showReplacementDialog(String slotId, String position) async {
  final availablePlayers = await _fetchAvailablePlayers(position);
  
  showModalBottomSheet(
    context: context,
    builder: (_) => _ReplacementPanel(
      players: availablePlayers,
      position: position,
      onSelect: (playerId) => _updatePosition(slotId, playerId, position),
    ),
  );
}

  Future<List<Map<String, dynamic>>> _fetchAvailablePlayers(String position) async {
    final xiSnapshot = await _firestore.collection('clubs')
        .doc(_clubId)
        .collection('Playing_XI')
        .get();
        
    final currentPlayerIds = xiSnapshot.docs
      .map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['player_uid'] as String?;
      })
        .where((id) => id != null)
        .toSet();

    final playersSnapshot = await _firestore.collection('clubs')
        .doc(_clubId)
        .collection('players'). where('position', isEqualTo: position)
        .get();

    return playersSnapshot.docs
        .where((doc) => !currentPlayerIds.contains(doc.id))
        .map((doc) => {
        'id': doc.id, 
        ...doc.data(),
      })
        .toList();
  }

  Future<void> _updatePosition(String slotId, String playerId, String position) async {
    final playerDoc = await _firestore.collection('clubs').doc(_clubId).collection('players').doc(playerId).get();
    
    if (playerDoc.exists) {
    await _firestore.collection('clubs').doc(_clubId)
        .collection('Playing_XI').doc(slotId)
        .set({
          ...playerDoc.data()!,
          'player_uid': playerId,
          'position': position,
          'last_updated': FieldValue.serverTimestamp(),
        });
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: _backgroundDecoration(),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _clubId == null 
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<QuerySnapshot>(
                      stream: _firestore.collection('clubs').doc(_clubId)
                          .collection('Playing_XI')
                          .orderBy(FieldPath.documentId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        return _buildFormationGrid(snapshot.data!.docs);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('PLAYING XI', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
        ],
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
}

class _PositionCard extends StatelessWidget {
  final String position;
  final Map<String, dynamic>? player;
  final VoidCallback onTap;

  const _PositionCard({
    required this.position,
    this.player,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(player != null ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: player != null ? Colors.green : Colors.white30,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Position with overflow fix
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  position,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            if (player != null) ...[
              const SizedBox(height: 8),
              // Player name with overflow fix
              Flexible(
                child: Text(
                  player!['name'] ?? 'No Name', 
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Player position with overflow fix
              Flexible(
                child: Text(
                  player?['position']?.toString() ?? 'No Position',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplacementPanel extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final String position;
  final ValueChanged<String> onSelect;

  const _ReplacementPanel({
    required this.position,
    required this.players,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _buildPlayerList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Replacement',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: players.length,
      itemBuilder: (context, index) {
        final player = players[index];
        final playerId = player['id'] as String?;
        
        return _buildPlayerItem(context, player, playerId, index);
      },
    );
  }

  Widget _buildPlayerItem(BuildContext context, Map<String, dynamic> player, String? playerId, int index) {
  return GestureDetector(
    key: Key(playerId ?? 'player_$index'),
    onTap: playerId != null ? () {
      debugPrint('Tapping player: $playerId');
      onSelect(playerId);
      Navigator.pop(context);
    } : null,
    behavior: HitTestBehavior.opaque,
    child: Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const SizedBox(width: 16),
          _buildPlayerAvatar(player),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player['name'] ?? 'Unknown Player',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  player['position'] ?? 'No Position',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (playerId != null)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.arrow_forward_ios, size: 16),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildPlayerAvatar(Map<String, dynamic> player) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.indigo[100],
      child: Text(
        (player['name']?.isNotEmpty ?? false)
            ? player['name'][0].toUpperCase()
            : '?',
        style: TextStyle(
          color: Colors.indigo[800],
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  
} 