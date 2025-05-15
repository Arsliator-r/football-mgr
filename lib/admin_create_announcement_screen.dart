import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key});

  @override
  State<CreateAnnouncementScreen> createState() => _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> 
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  late AnimationController _fabController;

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
        appBar: AppBar(
          title: const Text('Announcements'),
          backgroundColor: Colors.indigo.shade900,
        ),
        body: _buildAnnouncementBody(),
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(
            parent: _fabController,
            curve: Curves.fastOutSlowIn,
          ),
          child: FloatingActionButton(
            onPressed: () => _showAnnouncementDialog(),
            backgroundColor: Colors.indigoAccent,
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementBody() {
    return Container(
      decoration: _backgroundDecoration(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Expanded(child: _buildAnnouncementList()),
        ],
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

  Widget _buildAnnouncementList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('announcements')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No announcements yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18
              ),
            ),
          );
        }

        return AnimatedList(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          initialItemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index, animation) {
            final doc = snapshot.data!.docs[index];
            return _buildAnnouncementItem(doc, animation);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementItem(DocumentSnapshot doc, Animation<double> animation) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        margin: const EdgeInsets.only(bottom: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          title: Text(
            data['title'] ?? 'No Title',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['message'] ?? 'No Message'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _getTargetText(data['target']),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showAnnouncementDialog(existing: doc),
          ),
        ),
      ),
    );
  }

  String _getTargetText(String target) {
    return switch (target) {
      'managers' => 'Managers Only',
      'players' => 'Players Only',
      _ => 'All Users',
    };
  }

  void _showAnnouncementDialog({DocumentSnapshot? existing}) {
    final isEdit = existing != null;
    final dialog = AnnouncementDialog(
      initialTitle: existing?['title'],
      initialMessage: existing?['message'],
      initialTarget: existing?['target'],
      onSave: (title, message, target) => _handleAnnouncementSave(
        isEdit: isEdit,
        docId: existing?.id,
        title: title,
        message: message,
        target: target,
      ),
    );
    
    showDialog(context: context, builder: (context) => dialog);
  }

  Future<void> _handleAnnouncementSave({
    required bool isEdit,
    required String title,
    required String message,
    required String target,
    String? docId,
  }) async {
    try {
      final batch = _firestore.batch();
      final docRef = docId != null 
          ? _firestore.collection('announcements').doc(docId)
          : _firestore.collection('announcements').doc();

      batch.set(docRef, {
        'title': title,
        'message': message,
        'target': target,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!isEdit) {
        await _sendNotifications(batch, target, docRef.id);
      }

      await batch.commit();
      
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text('Announcement ${isEdit ? 'updated' : 'sent'}!'))
        );
      }
    } catch (e) {
      if (mounted) {
        _scaffoldKey.currentState?.showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _sendNotifications(WriteBatch batch, String target, String docId) async {
    final targetRoles = switch (target) {
      'managers' => ['manager'],
      'players' => ['player'],
      _ => ['manager', 'player']
    };

    final users = await _firestore.collection('users')
        .where('role', whereIn: targetRoles)
        .get();

    for (final user in users.docs) {
      final notifRef = user.reference.collection('notifications').doc(docId);
      batch.set(notifRef, {
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }
}

class AnnouncementDialog extends StatefulWidget {
  final String? initialTitle;
  final String? initialMessage;
  final String? initialTarget;
  final Function(String, String, String) onSave;

  const AnnouncementDialog({
    super.key,
    this.initialTitle,
    this.initialMessage,
    this.initialTarget,
    required this.onSave,
  });

  @override
  State<AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<AnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late String _selectedTarget;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _messageController = TextEditingController(text: widget.initialMessage);
    _selectedTarget = widget.initialTarget ?? 'both';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialTitle == null ? 'New Announcement' : 'Edit Announcement'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildMessageField(),
              const SizedBox(height: 16),
              _buildTargetDropdown(),
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
          onPressed: _validateAndSubmit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      decoration: const InputDecoration(labelText: 'Title'),
      validator: (value) => value?.isEmpty ?? true ? 'Title required' : null,
    );
  }

  Widget _buildMessageField() {
    return TextFormField(
      controller: _messageController,
      decoration: const InputDecoration(labelText: 'Message'),
      maxLines: 4,
      validator: (value) => value?.isEmpty ?? true ? 'Message required' : null,
    );
  }

  Widget _buildTargetDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedTarget,
      decoration: const InputDecoration(labelText: 'Send To'),
      items: const [
        DropdownMenuItem(value: 'both', child: Text('All Users')),
        DropdownMenuItem(value: 'managers', child: Text('Managers Only')),
        DropdownMenuItem(value: 'players', child: Text('Players Only')),
      ],
      onChanged: (value) => setState(() => _selectedTarget = value!),
    );
  }

  void _validateAndSubmit() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        _titleController.text.trim(),
        _messageController.text.trim(),
        _selectedTarget,
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}