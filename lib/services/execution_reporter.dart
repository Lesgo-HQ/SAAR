import '../models/execution_report.dart';
import '../models/replay_session.dart';

class ExecutionReporter {
  final List<ExecutionReport> _reports = [];

  List<ExecutionReport> get reports => List.unmodifiable(_reports);

  ExecutionReport report(ReplaySession session, {String? stoppedReason}) {
    final report = ExecutionReport(
      runId: session.runId,
      flowId: session.flow.flowId,
      status: session.status.name,
      currentStep: session.status == ReplayStatus.completed ? session.currentStep : session.currentStep + 1,
      totalSteps: session.flow.steps.length,
      recoveries: session.recoveryAttempts,
      clarifications: session.clarificationCount,
      stoppedReason: _redact(stoppedReason),
      createdAt: DateTime.now(),
    );
    _reports.add(report);
    return report;
  }

  String? _redact(String? value) {
    if (value == null) return null;
    return RegExp(r'password|otp|pin|cvv|cvc|card number|bank account|upi|ifsc', caseSensitive: false).hasMatch(value)
        ? 'Sensitive state detected'
        : value;
  }
}
