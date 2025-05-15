import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:football_mgr/admin_venue_management.dart';

class CreateMatchSchedule extends StatefulWidget {
  const CreateMatchSchedule({super.key});

  @override
  State<CreateMatchSchedule> createState() => _CreateMatchScheduleState();
}

class _CreateMatchScheduleState extends State<CreateMatchSchedule> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  // Add this in the state class variables
  final CollectionReference _venuesRef = FirebaseFirestore.instance.collection('venues');

  // Modified to include document IDs
  Stream<List<Map<String, String>>> get teams {
    return _firestore.collection("clubs").snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => {
        'id': doc.id,
        'name': doc['club_name'].toString()
      }).toList()
    );
  }

  // Modified to include document IDs
  Stream<List<Map<String, String>>> get venues {
    return _venuesRef.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => ({
        'id': doc.id,
        'name': doc['name'].toString()
      })).toList()
    );
  }

  // Add this function to manage venues (call from admin dashboard)
  void _manageVenues(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VenueManagementScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: _buildBackgroundDecoration(),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildFixtureList(),
                ],
              ),
            ),
          ),
        ),
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
            'MATCH SCHEDULING',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FloatingActionButton(
              onPressed: () => _showMatchDialog(context),
              backgroundColor: Colors.indigoAccent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          TextButton(
            child: const Text("Manage Venues", style: TextStyle(
              color: Colors.white,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w800,
              )),
            onPressed: () => _manageVenues(context),
          ),
          const Divider(color: Colors.white54),
        ],
      ),
    );
  }

  Widget _buildFixtureList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection("fixtures")
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No scheduled matches yet.",
                style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ));
          }

          return AnimatedList(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            initialItemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index, animation) {
              final match = snapshot.data!.docs[index];
              return _buildFixtureItem(match, animation);
            },
          );
        },
      ),
    );
  }

  Widget _buildFixtureItem(DocumentSnapshot match, Animation<double> animation) {
    final data = match.data() as Map<String, dynamic>;
    
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: FutureBuilder(
            future: Future.wait([
              (data['team1Ref'] as DocumentReference).get(),
              (data['team2Ref'] as DocumentReference).get(),
              (data['venueRef'] as DocumentReference).get(),
            ]),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const CircularProgressIndicator();
              
              final team1Doc = snapshot.data![0];
              final team2Doc = snapshot.data![1];
              final venueDoc = snapshot.data![2];

              return Column(
                children: [
                  _buildTeamRow(
                    team1Doc.exists ? team1Doc['club_name'] : '[Deleted Team]',
                    team2Doc.exists ? team2Doc['club_name'] : '[Deleted Team]',
                  ),
                  _buildMatchDetail('Venue', venueDoc.exists ? venueDoc['name'] : '[Deleted Venue]'),
                  _buildMatchDetail('Date', data['date']),
                  _buildMatchDetail('Time', data['time']),
                  _buildActionButtons(match),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRow(String team1, String team2) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text(team1, style: const TextStyle(fontWeight: FontWeight.bold)),
        const Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
        Text(team2, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMatchDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildActionButtons(DocumentSnapshot match) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showMatchDialog(context, match: match),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDelete(match.id),
        ),
      ],
    );
  }

  void _showMatchDialog(BuildContext context, {DocumentSnapshot? match}) {
    final isEditing = match != null;

    showDialog(
      context: context,
      builder: (context) => MatchDialog(
        scaffoldKey: _scaffoldKey,
        teams: teams,
        venues: venues,
        initialData: isEditing ? match.data() as Map<String, dynamic> : null,
        onSave: (data) => isEditing 
            ? _updateMatch(match.id, data) 
            : _createMatch(data),
      ),
    );
  }

  Future<void> _createMatch(Map<String, dynamic> data) async {
    try {
      await _firestore.collection("fixtures").add({
        'team1Ref': data['team1Ref'],
        'team2Ref': data['team2Ref'],
        'venueRef': data['venueRef'],
        'date': data['date'],
        'time': data['time'],
        'timestamp': FieldValue.serverTimestamp(),
      });
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Match created successfully!'))
      );
    } catch (e) {
      _showError('Failed to create match: ${e.toString()}');
    }
  }

  Future<void> _updateMatch(String id, Map<String, dynamic> data) async {
    try {
      await _firestore.collection("fixtures").doc(id).update(data);
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Match updated successfully!'))
      );
    } catch (e) {
      _showError('Failed to update match: ${e.toString()}');
    }
  }

  void _confirmDelete(String matchId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this fixture?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _firestore.collection("fixtures").doc(matchId).delete();
              Navigator.pop(context);
              _scaffoldKey.currentState?.showSnackBar(
                const SnackBar(content: Text('Match deleted'))
              );
            },
            child: const Text('Delete'),
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
}

class MatchDialog extends StatefulWidget {
  final GlobalKey<ScaffoldMessengerState> scaffoldKey;
  final Stream<List<Map<String, String>>> teams;
  final Stream<List<Map<String, String>>> venues;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic>) onSave;

  const MatchDialog({
    super.key,
    required this.scaffoldKey,
    required this.teams,
    required this.venues,
    this.initialData,
    required this.onSave,
  });

  @override
  State<MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends State<MatchDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _team1Id;
  String? _team2Id;
  String? _venueId;
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _team1Id = (widget.initialData!['team1Ref'] as DocumentReference).id;
      _team2Id = (widget.initialData!['team2Ref'] as DocumentReference).id;
      _venueId = (widget.initialData!['venueRef'] as DocumentReference).id;
      _dateController.text = widget.initialData!['date'];
      _timeController.text = widget.initialData!['time'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'New Match' : 'Edit Match'),
      content: StreamBuilder<List<Map<String, String>>>(
        stream: widget.teams,
        builder: (context, teamSnapshot) {
          if (!teamSnapshot.hasData) return const CircularProgressIndicator();
          
          return StreamBuilder<List<Map<String, String>>>(
            stream: widget.venues,
            builder: (context, venueSnapshot) {
              if (!venueSnapshot.hasData) return const CircularProgressIndicator();

              return SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTeamDropdown(
                      teamSnapshot.data!, 
                      _team1Id, 
                      'Team 1', 
                      (value) => setState(() => _team1Id = value)
                    ),
                    const SizedBox(height: 15),
                    _buildTeamDropdown(
                      teamSnapshot.data!.where((t) => t['id'] != _team1Id).toList(),
                      _team2Id, 
                      'Team 2', 
                      (value) => setState(() => _team2Id = value)
                    ),
                    const SizedBox(height: 15),
                    _buildVenueDropdown(venueSnapshot.data!),
                    const SizedBox(height: 15),
                    _buildDateTimeFields(),
                  ],
                ),
              );
            },
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validateAndSubmit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTeamDropdown(List<Map<String, String>> teams, String? value, String label, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      items: teams.map((team) => DropdownMenuItem(
        value: team['id'],
        child: Text(team['name']!),
      )).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildVenueDropdown(List<Map<String, String>> venues) {
    return DropdownButtonFormField<String>(
      value: _venueId,
      decoration: const InputDecoration(labelText: "Venue"),
      items: venues.map((venue) => DropdownMenuItem(
        value: venue['id'],
        child: Text(venue['name']!),
      )).toList(),
      onChanged: (value) => setState(() => _venueId = value),
    );
  }

  Widget _buildDateTimeFields() {
    return Column(
      children: [
        TextFormField(
          controller: _dateController,
          decoration: const InputDecoration(labelText: "Date"),
          readOnly: true,
          onTap: () => _selectDate(),
          validator: (value) => value?.isEmpty ?? true ? 'Required field' : null,
        ),
        TextFormField(
          controller: _timeController,
          decoration: const InputDecoration(labelText: "Time"),
          readOnly: true,
          onTap: () => _selectTime(),
          validator: (value) => value?.isEmpty ?? true ? 'Required field' : null,
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      _timeController.text = time.format(context);
    }
  }

  void _validateAndSubmit() {
    if (_team1Id == null || _team2Id == null || _venueId == null) {
      widget.scaffoldKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Please select all required fields!'))
      );
      return;
    }

    widget.onSave({
      'team1Ref': FirebaseFirestore.instance.doc('clubs/$_team1Id'),
      'team2Ref': FirebaseFirestore.instance.doc('clubs/$_team2Id'),
      'venueRef': FirebaseFirestore.instance.doc('venues/$_venueId'),
      'date': _dateController.text,
      'time': _timeController.text,
    });

    Navigator.pop(context);
  }
  

  
} 