import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VenueManagementScreen extends StatefulWidget {
  const VenueManagementScreen({super.key});

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  List<DocumentSnapshot> _venues = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: _buildBackgroundDecoration(),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildVenueList(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVenueDialog(context),
        backgroundColor: Colors.indigoAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'VENUE MANAGEMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildVenueList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('venues').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
    final newVenues = snapshot.data!.docs;
    
    // Handle additions
    for (int i = _venues.length; i < newVenues.length; i++) {
      _venues.add(newVenues[i]);
      _listKey.currentState?.insertItem(i);
    }
    
    // Handle removals
    for (int i = _venues.length - 1; i >= 0; i--) {
      if (!newVenues.contains(_venues[i])) {
        final removedItem = _venues[i];
        _venues.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildVenueItem(removedItem, animation),
        );
      }
    }

    for (int i = 0; i < _venues.length; i++) {
      if (i < newVenues.length && _venues[i] != newVenues[i]) {
        _venues[i] = newVenues[i];
      }
    }
  }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (!snapshot.hasData || _venues.isEmpty) {
            return Center(
              child: Text(
                "No venues added yet",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18
                ),
              ),
            );
          }

          return AnimatedList(
            key: _listKey,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            initialItemCount: _venues.length,
            itemBuilder: (context, index, animation) {
              if (index >= _venues.length) return const SizedBox.shrink();
              return _buildVenueItem(_venues[index], animation);
            },
          );
        },
      ),
    );
  }

  Widget _buildVenueItem(DocumentSnapshot venue, Animation<double> animation) {
    final data = venue.data() as Map<String, dynamic>;
    
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  data['name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500
                  ),
                ),
              ),
              _buildActionButtons(venue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(DocumentSnapshot venue) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditVenueDialog(context, venue),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteVenue(venue.id),
        ),
      ],
    );
  }

  void _showAddVenueDialog(BuildContext context) {
    _nameController.clear();
    _showVenueDialog(context, isEditing: false);
  }

  void _showEditVenueDialog(BuildContext context, DocumentSnapshot venue) {
    final data = venue.data() as Map<String, dynamic>;
    _nameController.text = data['name'];
    _showVenueDialog(context, isEditing: true, venue: venue);
  }

  void _showVenueDialog(BuildContext outerContext, 
      {bool isEditing = false, DocumentSnapshot? venue}) {
    showDialog(
      context: outerContext,
      builder: (innerContext) => AlertDialog(
        title: Text(isEditing ? 'Edit Venue' : 'Add New Venue'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Venue Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(innerContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => _handleVenueSave(innerContext, isEditing, venue),
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVenueSave(BuildContext innerContext, bool isEditing, DocumentSnapshot? venue) async {
    if (_nameController.text.isEmpty) return;

    try {
      if (isEditing && venue != null) {
        await venue.reference.update({'name': _nameController.text});
      } else {
        await _firestore.collection('venues').add({
          'name': _nameController.text,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      Navigator.pop(innerContext);
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(content: Text('Venue ${isEditing ? 'updated' : 'added'}!'))
      );
    } catch (e) {
      _showError('Operation failed: ${e.toString()}');
    }
  }

  void _confirmDeleteVenue(String venueId) async {
  // Find index in local venues list
  final index = _venues.indexWhere((doc) => doc.id == venueId);
  if (index == -1) return; // Not found in local list

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text('Are you sure you want to delete this venue?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            // Remove from UI first
            final removedItem = _venues.removeAt(index);
            _listKey.currentState?.removeItem(
              index,
              (context, animation) => _buildVenueItem(removedItem, animation),
            );

            // Then delete from Firestore
            await _firestore.collection('venues').doc(venueId).delete();
            
            Navigator.pop(context);
            _scaffoldKey.currentState?.showSnackBar(
              const SnackBar(content: Text('Venue deleted'))
            );
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

  void _showError(String message) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red)
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}