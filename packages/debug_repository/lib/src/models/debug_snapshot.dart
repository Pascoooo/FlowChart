import 'package:equatable/equatable.dart';
import 'debug_session.dart';

/// Snapshot dello stato del debug per supportare undo/redo
class DebugSnapshot extends Equatable {
  final DebugSession session;
  final DateTime timestamp;

  const DebugSnapshot({
    required this.session,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [session, timestamp];
}

