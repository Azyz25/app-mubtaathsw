import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mubtaath/core/services/dio_client.dart';

// Holds live participant counts for every room the app knows about.
// Seeded from the rooms list on load; updated in real-time by RoomCubit
// whenever it receives UserJoined / UserLeft / ParticipantUpdated from the WS.
// Registered globally in MultiBlocProvider so home cards, community cards,
// the detail sheet, and the live room all share one source of truth.

class RoomStatusState {
  final Map<String, int> counts; // roomId → participantCount
  const RoomStatusState({this.counts = const {}});

  RoomStatusState withCount(String roomId, int count) =>
      RoomStatusState(counts: {...counts, roomId: count});

  RoomStatusState withAll(Map<String, int> extra) =>
      RoomStatusState(counts: {...counts, ...extra});
}

class RoomStatusCubit extends Cubit<RoomStatusState> {
  RoomStatusCubit() : super(const RoomStatusState());

  // Called by RoomCubit whenever a WS count event arrives for a specific room.
  void updateCount(String roomId, int count) {
    if (isClosed || roomId.isEmpty) return;
    emit(state.withCount(roomId, count));
  }

  // Called after HomeCubit / CommunityCubit load their room lists so the
  // cards immediately show the API-provided count before any WS event fires.
  void seedCounts(Map<String, int> counts) {
    if (isClosed || counts.isEmpty) return;
    emit(state.withAll(counts));
  }

  // Optional: re-fetch all room counts on-demand (pull-to-refresh, app resume).
  Future<void> fetchAllRoomStats() async {
    try {
      final resp = await appDio.get(
        '/rooms',
        queryParameters: {'status': 'active'},
      );
      final data = resp.data['data'] as List<dynamic>? ?? [];
      if (isClosed || data.isEmpty) return;
      final map = <String, int>{};
      for (final r in data) {
        final id    = r['id']             as String? ?? '';
        final count = (r['listenerCount'] as num?)?.toInt() ?? 0;
        if (id.isNotEmpty) map[id] = count;
      }
      if (map.isNotEmpty) emit(state.withAll(map));
    } catch (_) {}
  }
}
