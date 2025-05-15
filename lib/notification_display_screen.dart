import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DisplayNotificationScreen extends StatelessWidget {
  final String userId;
  
  const DisplayNotificationScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
       body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurpleAccent,
              Colors.indigoAccent,
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            stops: [0.55, 1.0],
          ),
        ),
        child: _buildNotificationContent(),
      ),
    );
  }

  Widget _buildNotificationContent() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No notifications',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 18,
              ),
            ),
          );
        }

        return _buildNotificationList(snapshot.data!.docs);
      },
    );
  }


  Widget _buildNotificationList(List<QueryDocumentSnapshot> docs) {
    final announcementIds = docs.map((doc) => doc.id).toList();

    return FutureBuilder<Map<String, DocumentSnapshot>>(
      future: _fetchAllAnnouncements(announcementIds),
      builder: (context, announcementSnapshot) {
        if (announcementSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final announcements = announcementSnapshot.data ?? {};
        
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final notifDoc = docs[index];
            return _buildNotificationItem(notifDoc, announcements);
          },
        );
      },
    );
  }

  Future<Map<String, DocumentSnapshot>> _fetchAllAnnouncements(List<String> ids) async {
    final snapshots = await Future.wait(
      ids.map((id) => FirebaseFirestore.instance
        .collection('announcements')
        .doc(id)
        .get()
      )
    );

    return {for (var doc in snapshots) doc.id: doc};
  }

  Widget _buildNotificationItem(QueryDocumentSnapshot notifDoc, Map<String, DocumentSnapshot> announcements) {
    final read = notifDoc['read'] ?? false;
    final announcement = announcements[notifDoc.id];
    final title = announcement?['title'] ?? 'No title';
    final message = announcement?['message'] ?? 'No message';

    return Dismissible(
      key: Key(notifDoc.id),
      background: Container(color: Colors.red),
      onDismissed: (_) => notifDoc.reference.delete(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: read ? Colors.grey[100] : Colors.blue[50],
        ),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(
            fontWeight: read ? FontWeight.normal : FontWeight.bold
          )),
          trailing: Icon(
            read ? Icons.mark_email_read : Icons.mark_email_unread,
            color: read ? Colors.grey : Colors.blue,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(message),
            )
          ],
          onExpansionChanged: (expanded) => _handleExpansion(expanded, read, notifDoc),
        ),
      ),
    );
  }

  Future<void> _handleExpansion(bool expanded, bool read, QueryDocumentSnapshot doc) async {
    if (expanded && !read) {
      await doc.reference.update({'read': true});
    }
  }
}