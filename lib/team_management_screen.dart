import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';


class MangerTeamManagementScreen extends StatefulWidget {
  const MangerTeamManagementScreen({super.key});

  @override
  State<MangerTeamManagementScreen> createState() => _MangerTeamManagementScreenState();
}

class _MangerTeamManagementScreenState extends State<MangerTeamManagementScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  String? _clubId;
  FirebaseApp? _secondaryApp;
  final _apiTimeout = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _loadClubId();
  }

  Future<void> _initializeFirebase() async {
    _secondaryApp = await Firebase.initializeApp(
      name: 'Secondary',
      options: Firebase.app().options,
    );
  }

  Future<void> _loadClubId() async {
    try {
      final snapshot = await _firestore.collection("clubs")
          .where("manager_id", isEqualTo: _auth.currentUser!.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() => _clubId = snapshot.docs.firstOrNull?.id);
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red)
    );
  }

  void _showSuccess(String message) {
    _scaffoldKey.currentState?.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green)
    );
  }

  void _handleAddPlayer() => showDialog(
    context: context,
    builder: (_) => _PlayerFormDialog(
      clubId: _clubId!,
      secondaryApp: _secondaryApp!,
      onSuccess: () => _showSuccess("Player added successfully!"),
      onError: _showError,
    ),
  );

  void _handleEditPlayer(String id, Map<String, dynamic> data) => showDialog(
    context: context,
    builder: (_) => _PlayerFormDialog.edit(
      clubId: _clubId!,
      playerId: id,
      initialData: data,
      secondaryApp: _secondaryApp!,
      onSuccess: () => _showSuccess("Player updated successfully!"),
      onError: _showError,
    ),
  );

  /// 1️⃣ Confirmation dialog for delete
  void _confirmDeletePlayer(String id, String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this player?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _handleDeletePlayer(id, email);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeletePlayer(String id, String email) async {
    try {
      // Call deletion API
      final response = await http
          .post(
            Uri.parse('http://192.168.100.11:5000/delete_user'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(_apiTimeout);

      if (response.statusCode != 200) {
        throw Exception('API error: ${response.body}');
      }

      // Firestore batch delete
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('users').doc(id));
      batch.delete(_firestore.collection('clubs').doc(_clubId).collection('players').doc(id));

      final xiDocs = await _firestore
          .collection('clubs')
          .doc(_clubId)
          .collection('Playing_XI')
          .where('player_uid', isEqualTo: id)
          .get();
      for (final doc in xiDocs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      _showSuccess('Player deleted successfully!');
    } on TimeoutException {
      _showError('Server took too long. Please try again.');
    } catch (e) {
      _showError('Deletion failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        body: Container(
          decoration: _backgroundDecoration(),
          child: Column(
            children: [
              _buildHeader(),
              _buildPlayerList(),
            ],
          ),
        ),
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
        stops: const [0.55, 1.0],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        children: [
          const Text(
            'PLAYER MANAGEMENT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Add Player'),
              onPressed: _clubId == null
                  ? () => _showError('Club data not loaded yet')
                  : _handleAddPlayer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerList() {
    if (_clubId == null) return const Center(child: CircularProgressIndicator());

    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection("clubs").doc(_clubId)
            .collection("players").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _ErrorWidget(error: snapshot.error.toString());
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final players = snapshot.data!.docs;
          if (players.isEmpty) return const _EmptyState();

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: players.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = players[index];
              final data = doc.data() as Map<String, dynamic>;
              return _PlayerCard(
                data: data,
                onEdit: () => _handleEditPlayer(doc.id, data),
                onDelete: () => _confirmDeletePlayer(doc.id, data['email']),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlayerFormDialog extends StatefulWidget {
  
  final String clubId;
  final FirebaseApp secondaryApp;
  final Map<String, dynamic>? initialData;
  final String? playerId;
  final VoidCallback onSuccess;
  final ValueChanged<String> onError;

  const _PlayerFormDialog({
    required this.clubId,
    required this.secondaryApp,
    required this.onSuccess,
    required this.onError,
    this.playerId,
    this.initialData,
  });

  factory _PlayerFormDialog.edit({
    required String clubId,
    required String playerId,
    required Map<String, dynamic> initialData,
    required VoidCallback onSuccess,
    required ValueChanged<String> onError,
    required FirebaseApp secondaryApp,
  }){
    return _PlayerFormDialog(
      clubId: clubId,
      playerId: playerId,
      initialData: initialData,
      onSuccess: onSuccess,
      onError: onError,
      secondaryApp: secondaryApp,
    );
  }

  bool get isEditing => initialData != null;

  @override
  State<_PlayerFormDialog> createState() => _PlayerFormDialogState();
}

class _PlayerFormDialogState extends State<_PlayerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late String? _selectedPosition;
  late int? _weakFoot;
  late String? _preferredFoot;
  String? _suggestedPosition;

  final _positionsMap = {
    'GK': 'Goal Keeper',
    'CB': 'Center Back 1',
    'CAM': 'Center Back 1',
    'CDM': 'Center Back 2',
    'RB': 'Right Back',
    'LB': 'Left Back',
    'CM': 'Central Midfielder',
    'RM': 'Right Midfielder',
    'LM': 'Left Midfielder',
    'LW': 'Left Winger',
    'RW': 'Right Winger',
    'ST': 'Striker',
  };
  final _positions = ['Goal Keeper', 'Center Back 1', 'Center Back 2', 'Right Back', 'Left Back', 'Central Midfielder', 'Right Midfielder','Left Midfielder', 'Left Winger', 'Right Winger', 'Striker'];
  final _skills = ['defending', 'shooting', 'passing', 'dribbling', 'physicality', 'pace'];

  final _weakFootOptions = [1, 2, 3, 4, 5];
  final _preferredFootOptions = ['Right', 'Left'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final data = widget.initialData ?? {};
    _controllers = {
      for (var skill in _skills) 
        skill: TextEditingController(text: data[skill]?.toString()),
      'name': TextEditingController(text: data['name']),
      'email': TextEditingController(text: data['email']),
      'password': TextEditingController(),
      'height_cm': TextEditingController(text: data['height_cm']?.toString()),
      'weak_foot': TextEditingController(text: data['weak_foot']?.toString()),
    };
    _selectedPosition = data['position'];
    _weakFoot = data['weak_foot'];
    _preferredFoot = data['preferred_foot'];

    for (final controller in _controllers.values) {
      controller.addListener(() => setState(() {}));
   }

  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.isEditing) {
        await _updatePlayer();
      } else {
        await _createPlayer();
      }
      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      widget.onError(e.toString());
    }
  }

  Future<void> _createPlayer() async {
    try {
      final auth = FirebaseAuth.instanceFor(app: widget.secondaryApp);
      final credential = await auth.createUserWithEmailAndPassword(
        email: _controllers['email']!.text.trim(),
        password: _controllers['password']!.text.trim(),
      );

      final batch = FirebaseFirestore.instance.batch();

      batch.set(
        FirebaseFirestore.instance.collection("users").doc(credential.user!.uid), 
        {
          'email': _controllers['email']!.text.trim(),
          'role': 'player',
          'username': _controllers['name']!.text.trim(),
        }
      );

      batch.set(
        FirebaseFirestore.instance
            .collection("clubs")
            .doc(widget.clubId)
            .collection("players")
            .doc(credential.user!.uid),
        {
          ..._getPlayerData(),
          'team_id': FirebaseAuth.instance.currentUser!.uid,
          'created_at': FieldValue.serverTimestamp(),
        }
      );

      await batch.commit();
      widget.onSuccess();
    } catch (e) {
      widget.onError('Failed to create player: ${e.toString()}');
    }
  }

  Future<void> _updatePlayer() async {
    await FirebaseFirestore.instance
        .collection("clubs")
        .doc(widget.clubId)
        .collection("players")
        .doc(widget.playerId)
        .update(_getPlayerData());
  }

  Map<String, dynamic> _getPlayerData() {
    return {
      'name': _controllers['name']!.text.trim(),
      'email': _controllers['email']!.text.trim(),
      'position': _selectedPosition,
      'weak_foot': _weakFoot,
      'preferred_foot': _preferredFoot,
      'height_cm': int.parse(_controllers['height_cm']!.text.trim()),
      for (var skill in _skills)
        skill: int.parse(_controllers[skill]!.text.trim()),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Player' : 'Add New Player'),
      content: Scaffold(
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField('name', 'Name'),
                if (!widget.isEditing) _buildTextField('email', 'Email'),
                if (!widget.isEditing) _buildTextField('password', 'Password', isPassword: true),
                _buildPreferredFootDropdown(),
                _buildWeakFootDropdown(),
                _buildHeightField(),
                ..._skills.map((skill) => _buildSkillField(skill)),
                _buildPositionDropdown(),
                _buildSuggestPositionButton(),
                
        
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  Widget _buildSuggestPositionButton() {
  final hasBasicData = _skills.every((skill) => _controllers[skill]!.text.isNotEmpty) &&
      _controllers['height_cm']!.text.isNotEmpty &&
      _weakFoot != null;

  return ElevatedButton.icon(
    onPressed: hasBasicData ? _suggestPosition : null,
    icon: const Icon(Icons.auto_fix_high),
    label: _suggestedPosition != null 
        ? Text('Suggested: $_suggestedPosition') 
        : const Text('Suggest Position'),
  );
}

  Widget _buildHeightField() {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: _controllers['height_cm'],
      decoration: const InputDecoration(labelText: 'Height (cm)'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (value) {
        final height = int.tryParse(value ?? '');
        return height == null || height < 100 || height > 250
            ? 'Enter valid height (100–250 cm)'
            : null;
      },
    ),
  );
}

Future<void> _suggestPosition() async {

  final isSkillsValid = _skills.every((skill) {
    final value = int.tryParse(_controllers[skill]!.text);
    return value != null && value >= 0 && value <= 100;
  });

  final isHeightValid = int.tryParse(_controllers['height_cm']!.text) != null &&
      int.parse(_controllers['height_cm']!.text) >= 100 &&
      int.parse(_controllers['height_cm']!.text) <= 250;

  if (!isSkillsValid || !isHeightValid || _weakFoot == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fill all skills, height and weak foot first')),
    );
    return;
  }

  try {
    final navigator = Navigator.of(context);
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Add client-side validation for skill values
    final skillsValid = _skills.every((skill) {
      final value = int.tryParse(_controllers[skill]!.text);
      return value != null && value >= 0 && value <= 100;
    });

    if (!skillsValid) {
      throw Exception('Skills must be between 0-100');
    }

    setState(() => _suggestedPosition = null); 
    final response = await http.post(
      Uri.parse("http://192.168.100.11:5001/predict"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "pace": int.parse(_controllers['pace']!.text),
        "shooting": int.parse(_controllers['shooting']!.text),
        "passing": int.parse(_controllers['passing']!.text),
        "dribbling": int.parse(_controllers['dribbling']!.text),
        "defending": int.parse(_controllers['defending']!.text),
        "physicality": int.parse(_controllers['physicality']!.text),
        "height_cm": int.parse(_controllers['height_cm']!.text),
        "weak_foot": _weakFoot,
      }),
    ).timeout(const Duration(seconds: 10));

    // Dismiss loading dialog
    navigator.pop();

    if (response.statusCode == 200) {
      final suggestion = jsonDecode(response.body);
      final suggestedPositionKey = suggestion['position'];

      setState(() {
        _suggestedPosition = _positionsMap[suggestedPositionKey] ?? suggestedPositionKey;
      });

    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } on TimeoutException {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request timed out')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}

  Widget _buildTextField(String key, String label, {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controllers[key],
        decoration: InputDecoration(labelText: label),
        obscureText: isPassword,
        enabled: !(widget.isEditing && key == 'email'),
        validator: (value) => value!.isEmpty ? '$label required' : null,
      ),
    );
  }

  Widget _buildPositionDropdown() {
    return DropdownButtonFormField<String>(
      
      value: _selectedPosition,
      decoration: const InputDecoration(labelText: 'Position'),
      items: _positions.map((pos) => DropdownMenuItem(value: pos, child: Text(pos))).toList(),
      onChanged: (value) => setState(() => _selectedPosition = value),
      validator: (value) => value == null ? 'Position required' : null,
    );
  }

  Widget _buildWeakFootDropdown() {
    return DropdownButtonFormField<int>(
      value: _weakFoot,
      decoration: const InputDecoration(labelText: 'Weak Foot (1–5)'),
      items: _weakFootOptions.map((num) => DropdownMenuItem(value: num, child: Text(num.toString()))).toList(),
      onChanged: (value) => setState(() => _weakFoot = value),
      validator: (value) => value == null ? 'Weak Foot required' : null,
    );
  }

  Widget _buildPreferredFootDropdown() {
    return DropdownButtonFormField<String>(
      value: _preferredFoot,
      decoration: const InputDecoration(labelText: 'Preferred Foot'),
      items: _preferredFootOptions.map((foot) => DropdownMenuItem(value: foot, child: Text(foot))).toList(),
      onChanged: (value) => setState(() => _preferredFoot = value),
      validator: (value) => value == null ? 'Preferred Foot required' : null,
    );
  }

  Widget _buildSkillField(String skill) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _controllers[skill],
        decoration: InputDecoration(labelText: '$skill (0-100)'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (value) {
          final num = int.tryParse(value ?? '');
          return num == null || num < 0 || num > 100 
              ? 'Enter 0-100' 
              : null;
        },
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _PlayerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlayerCard({
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.indigoAccent.shade700,
                child: const Icon(Icons.person, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['name'] ?? 'No Name', 
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['position'] ?? 'No Position'),
                    Text(data['email'] ?? 'No Email', 
                        style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final skill in ['defending', 'shooting', 'passing'])
                _SkillChip(skill: skill, value: data[skill]?.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String skill;
  final String? value;

  const _SkillChip({required this.skill, this.value});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('${skill.capitalize()}: ${value ?? '0'}'),
      backgroundColor: Colors.indigoAccent.shade100,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "No players found. Please add a player.",
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;

  const _ErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Error: $error",
        style: const TextStyle(color: Colors.red),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}