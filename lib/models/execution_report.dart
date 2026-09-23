class ExecutionReport {
  final String runId;
  final String flowId;
  final String status;
  final int currentStep;
  final int totalSteps;
  final int recoveries;
  final int clarifications;
  final String? stoppedReason;
  final DateTime createdAt;

  const ExecutionReport({
    required this.runId,
    required this.flowId,
    required this.status,
    required this.currentStep,
    required this.totalSteps,
    required this.recoveries,
    required this.clarifications,
    this.stoppedReason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'run_id': runId,
        'flow_id': flowId,
        'status': status,
        'current_step': currentStep,
        'total_steps': totalSteps,
        'recoveries': recoveries,
        'clarifications': clarifications,
        'stopped_reason': stoppedReason,
        'created_at': createdAt.toIso8601String(),
      };
}
