import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SetlistCloudRepo {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser!.uid;

  Future<String> createSetlist({
    required String title,
  }) async {
    final doc = await _db.collection('setlists').add({
      'title': title,
      'notes': '',
      'createdBy': _auth.currentUser?.uid,
      'members': [_auth.currentUser?.uid],
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSetlist(String setlistId) {
    return _db.collection('setlists').doc(setlistId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchItems(String setlistId) {
    return _db
        .collection('setlists')
        .doc(setlistId)
        .collection('items')
        .orderBy('position')
        .snapshots();
  }

  Future<void> addItem({
    required String setlistId,
    required String songId,
    required String title,
    required String baseKey,
    required int position,
    required String bodyChordPro,
    required String mode,
  }) async {
    await _db
        .collection('setlists')
        .doc(setlistId)
        .collection('items')
        .add({
      'songId': songId,
      'title': title,
      'baseKey': baseKey,
      'position': position,
      'steps': 0,
      'bodyChordPro': bodyChordPro,
      'mode': mode,
    });

    await _touch(setlistId);
  }

  Future<void> updateSteps({
    required String setlistId,
    required String itemId,
    required int steps,
  }) async {
    await _db
        .collection('setlists')
        .doc(setlistId)
        .collection('items')
        .doc(itemId)
        .update({'steps': steps});
    await _touch(setlistId);
  }

  Future<void> reorder({
    required String setlistId,
    required List<String> itemIdsInOrder,
  }) async {
    final batch = _db.batch();
    final itemsRef = _db.collection('setlists').doc(setlistId).collection('items');

    for (var i = 0; i < itemIdsInOrder.length; i++) {
      batch.update(itemsRef.doc(itemIdsInOrder[i]), {'position': i});
    }

    await batch.commit();
    await _touch(setlistId);
  }

  Future<void> removeItem({
    required String setlistId,
    required String itemId,
  }) async {
    await _db
        .collection('setlists')
        .doc(setlistId)
        .collection('items')
        .doc(itemId)
        .delete();
    await _touch(setlistId);
  }

  Future<void> inviteMember({
    required String setlistId,
    required String uid,
  }) async {
    final doc = _db.collection('setlists').doc(setlistId);
    await doc.update({
      'members': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _touch(String setlistId) async {
    await _db.collection('setlists').doc(setlistId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateSetlistMeta({
    required String setlistId,
    required String title,
    required String notes,
  }) async {
    await _db.collection('setlists').doc(setlistId).update({
      'title': title,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getSetlist(String id) {
    return _db.collection('setlists').doc(id).get();
  }

  Future<void> addCurrentUserToMembers(String setlistId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _db.collection('setlists').doc(setlistId).update({
      'members': FieldValue.arrayUnion([uid]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItemMeta({
    required String setlistId,
    required String itemId,
    required String title,
    required String baseKey,
  }) async {
    await _db
        .collection('setlists')
        .doc(setlistId)
        .collection('items')
        .doc(itemId)
        .update({
      'title': title,
      'baseKey': baseKey,
    });

    await _touch(setlistId);
  }

}