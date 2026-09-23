import 'flow.dart';
import 'screen_snapshot.dart';

enum ReplayStatus { idle, executing, recovering, waitingForUser, haltedSensitive, cancelled, failed, completed }

class ReplaySession {
  final String runId;
  final Flow flow;
  final Map<String, dynamic> slots;
  int currentStep;
  ReplayStatus status;
  int recoveryAttempts;
  int clarificationCount;
  ScreenSnapshot? lastScreen;

  ReplaySession({
    required this.runId,
    required this.flow,
    required this.slots,
    this.currentStep = 0,
    this.status = ReplayStatus.idle,
    this.recoveryAttempts = 0,
    this.clarificationCount = 0,
    this.lastScreen,
  });

  void start() => status = ReplayStatus.executing;
  void pause() => status = ReplayStatus.waitingForUser;
  void resume() => status = ReplayStatus.executing;
  void stop() => status = ReplayStatus.cancelled;
  void haltForSafety() => status = ReplayStatus.haltedSensitive;
  void fail() => status = ReplayStatus.failed;
  void complete() => status = ReplayStatus.completed;
}
