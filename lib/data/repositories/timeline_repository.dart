import '../models/timeline_event_model.dart';
import '../services/firestore_service.dart';

class TimelineRepository {
  const TimelineRepository({required this.firestoreService});

  final FirestoreService firestoreService;

  Future<List<TimelineEventModel>> getEvents() async {
    final snapshot = await firestoreService.userCollection('timeline').get();
    final events = snapshot.docs
        .map(
          (doc) => TimelineEventModel.fromJson({...doc.data(), 'id': doc.id}),
        )
        .toList();
    events.sort((a, b) => a.order.compareTo(b.order));
    return events;
  }

  Future<void> setEvent(TimelineEventModel event) async {
    await firestoreService
        .userCollection('timeline')
        .doc(event.id)
        .set(event.toJson());
  }

  Future<void> deleteEvent(String id) async {
    await firestoreService.userCollection('timeline').doc(id).delete();
  }
}
