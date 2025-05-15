import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class ClubManagementScreen extends StatefulWidget {
  const ClubManagementScreen({super.key});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> 
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _fabController;
  final List<DocumentSnapshot> _clubs = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey();
  final _apiTimeout = const Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
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
                  _buildClubList(),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(
            parent: _fabController,
            curve: Curves.fastOutSlowIn,
          ),
          child: FloatingActionButton(
            onPressed: () => _showAddClubDialog(),
            backgroundColor: Colors.indigoAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.deepPurpleAccent,
          Colors.indigoAccent,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: [0.55, 1.0],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text(
            'CLUB MANAGEMENT',
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

  Widget _buildClubList() {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("clubs").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _handleDataUpdate(snapshot.data!.docs);
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          return AnimatedList(
            key: _listKey,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            initialItemCount: _clubs.length,
            itemBuilder: (context, index, animation) {
              if (index >= _clubs.length) return const SizedBox.shrink();
              return _buildClubItem(_clubs[index], animation);
            },
          );
        },
      ),
    );
  }

  void _handleDataUpdate(List<DocumentSnapshot> newClubs) {
    // Handle additions
    for (int i = _clubs.length; i < newClubs.length; i++) {
      _clubs.add(newClubs[i]);
      _listKey.currentState?.insertItem(i);
    }

    // Handle removals
    for (int i = _clubs.length - 1; i >= 0; i--) {
      if (!newClubs.contains(_clubs[i])) {
        final removedItem = _clubs.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildClubItem(removedItem, animation),
        );
      }
    }
  }

  Widget _buildClubItem(DocumentSnapshot club, Animation<double> animation) {
    final data = club.data() as Map<String, dynamic>;
    
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              _buildClubHeader(data),
              _buildClubDetails(data),
              _buildActionButtons(club),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubHeader(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        CircleAvatar(
          backgroundColor: Colors.indigoAccent.shade700,
          radius: 40,
          child: const Icon(Icons.groups_3_outlined, size: 40, color: Colors.white),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data["club_name"],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(data["location"], style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }

  Widget _buildClubDetails(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        "Manager: ${data["manager_email"]}",
        style: const TextStyle(fontStyle: FontStyle.italic),
      ),
    );
  }

  Widget _buildActionButtons(DocumentSnapshot club) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _showEditClubDialog(club),
        ),
        IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _confirmDeleteClub(club),
        ),
      ],
    );
  }

  void _showAddClubDialog() {
    final dialog = ClubDialog(
      onCreate: _handleClubCreation,
      isEditing: false,
    );
    _showDialog(dialog);
  }

  void _showEditClubDialog(DocumentSnapshot club) {
    final data = club.data() as Map<String, dynamic>;
    final dialog = ClubDialog(
      initialName: data["club_name"],
      initialLocation: data["location"],
      onUpdate: (name, location) => _updateClub(club.id, name, location),
      isEditing: true,
    );
    _showDialog(dialog);
  }

  void _showDialog(Widget dialog) {
    showDialog(
      context: context,
      builder: (context) => dialog,
    );
  }

  Future<void> _handleClubCreation(String name, String location, Map<String, String> managerDetails) async {
    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: managerDetails["email"]!,
        password: managerDetails["password"]!,
      );

      await _firestore.collection("users").doc(userCredential.user!.uid).set({
        "email": managerDetails["email"],
        "role": "manager",
        "username": managerDetails["name"],
      });

      final clubRef = await _firestore.collection("clubs").add({
        "club_name": name,
        "location": location,
        "manager_email": managerDetails["email"],
        "manager_id": userCredential.user!.uid,
        "timestamp": FieldValue.serverTimestamp(),
      });

      _clubs.add(await clubRef.get());
      _listKey.currentState?.insertItem(_clubs.length - 1);
      
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Club & Manager created successfully!"))
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text("Creation failed: ${e.toString()}"))
        );
      }
    }
  }

  Future<void> _updateClub(String clubId, String name, String location) async {
    try {
      await _firestore.collection("clubs").doc(clubId).update({
        "club_name": name,
        "location": location,
      });

      final index = _clubs.indexWhere((c) => c.id == clubId);
      if (index != -1) {
        final oldItem = _clubs.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildClubItem(oldItem, animation),
        );

        final updatedClub = await _firestore.collection("clubs").doc(clubId).get();
        _clubs.insert(index, updatedClub);
        _listKey.currentState?.insertItem(index);
        
      }

      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Club updated successfully!"))
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text("Update failed: ${e.toString()}"))
        );
      }
    }
  }

  void _confirmDeleteClub(DocumentSnapshot club) {
    final data = club.data() as Map<String, dynamic>;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Delete this club and all associated data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => _handleClubDeletion(club.id, data),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleClubDeletion(String clubId, Map<String, dynamic> data) async {
    try {
      // Delete manager
      await _deleteUser(data["manager_email"]);
      
      // Delete players
      final playersSnapshot = await _firestore.collection("clubs").doc(clubId)
          .collection("players").get();
      
      for (final player in playersSnapshot.docs) {
        await _deleteUser(player["email"]);
      }

      // Delete club
      await _firestore.collection("clubs").doc(clubId).delete();

      // Update UI
      final index = _clubs.indexWhere((c) => c.id == clubId);
      if (index != -1) {
        final removedItem = _clubs.removeAt(index);
        _listKey.currentState?.removeItem(
          index,
          (context, animation) => _buildClubItem(removedItem, animation),
        );
      }

      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Deletion completed successfully!"))
        );
      }
    } on TimeoutException {
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          const SnackBar(content: Text("Operation timed out. Please try again."))
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text("Deletion failed: ${e.toString()}"))
        );
      }
    } finally {
      Navigator.pop(context);
    }
  }

  Future<void> _deleteUser(String email) async {
    final response = await http.post(
      Uri.parse('http://192.168.100.11:5000/delete_user'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    ).timeout(_apiTimeout);

    if (response.statusCode != 200) {
      throw Exception("API Error: ${response.body}");
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }
}

class ClubDialog extends StatefulWidget {
  final Function(String, String, Map<String, String>)? onCreate;
  final Function(String, String)? onUpdate;
  final String? initialName;
  final String? initialLocation;
  final bool isEditing;

  const ClubDialog({
    super.key,
    this.onCreate,
    this.onUpdate,
    this.initialName,
    this.initialLocation,
    required this.isEditing,
  });

  @override
  State<ClubDialog> createState() => _ClubDialogState();
}

class _ClubDialogState extends State<ClubDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _emailController;
  late TextEditingController _managerNameController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _locationController = TextEditingController(text: widget.initialLocation);
    _emailController = TextEditingController();
    _managerNameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Club' : 'New Club'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(_nameController, 'Club Name', validator: _validateRequired),
              _buildTextField(_locationController, 'Location', validator: _validateRequired),
              if (!widget.isEditing) ...[
                _buildTextField(_emailController, 'Manager Email', validator: _validateEmail),
                _buildTextField(_managerNameController, 'Manager Name', validator: _validateRequired),
                _buildTextField(_passwordController, 'Password', isPassword: true, validator: _validatePassword),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _handleSubmit,
          child: Text(widget.isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(labelText: label),
        validator: validator,
      ),
    );
  }

  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) return 'This field is required';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Invalid email format';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Minimum 6 characters required';
    return null;
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isEditing) {
      widget.onUpdate?.call(
        _nameController.text.trim(),
        _locationController.text.trim(),
      );
    } else {
      widget.onCreate?.call(
        _nameController.text.trim(),
        _locationController.text.trim(),
        {
          'email': _emailController.text.trim(),
          'name': _managerNameController.text.trim(),
          'password': _passwordController.text.trim(),
        },
      );
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _managerNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}