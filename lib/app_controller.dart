import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/flow.dart';
import 'models/action_trace_event.dart';
import 'services/accessibility_bridge.dart';
import 'services/asr_service.dart';
import 'services/llm_client.dart';
import 'services/flow_store.dart';
import 'services/flow_matcher.dart';
import 'services/replay_engine.dart';
import 'services/flow_synthesizer.dart';
import 'services/clarification_service.dart';
import 'services/intent_model.dart';
import 'services/slot_extractor.dart';

enum AppState { idle, listening, teaching, synthesizing, matching, executing, waitingForClarification, error }

class AppController extends ChangeNotifier {
  final AccessibilityBridge _bridge = AccessibilityBridge();
  final AsrService _asr = AsrService();
  late final LlmClient _llm;
  late final FlowStore _store;
  late final FlowMatcher _matcher;
  late final ReplayEngine _replay;
  late final FlowSynthesizer _synthesizer;
  late final ClarificationService _clarification;
  
  AppState _state = AppState.idle;
  AppState get state => _state;
  
  String _statusMessage = 'Ready';
  String get statusMessage => _statusMessage;
  
  List<Flow> _flows = [];
  List<Flow> get flows => _flows;
  
  // Teach mode state
  List<ActionTraceEvent> _actionTrace = [];
  String? _teachUtterance;
  Flow? _lastSynthesizedFlow;
  Flow? get lastSynthesizedFlow => _lastSynthesizedFlow;
  
  // Replay state
  ReplayState? _replayState;
  ReplayState? get replayState => _replayState;
  StreamSubscription? _replaySubscription;
  
  // Clarification
  String? _clarificationQuestion;
  String? get clarificationQuestion => _clarificationQuestion;
  
  bool _isAccessibilityEnabled = false;
  bool get isAccessibilityEnabled => _isAccessibilityEnabled;
  
  Future<void> initialize() async {
    _llm = LlmClient();
    _store = FlowStore();
    _clarification = ClarificationService();
    _matcher = FlowMatcher(_store, _llm, localModel: LocalIntentModel());
    _replay = ReplayEngine(_bridge, _llm, _clarification);
    _synthesizer = FlowSynthesizer(_llm);
    
    await _asr.initialize();
    await _store.loadEmbeddingsIntoMemory();
    _flows = await _store.getAllFlows();
    await checkAccessibility();
    notifyListeners();
  }
  
  Future<void> checkAccessibility() async {
    try {
      _isAccessibilityEnabled = await _bridge.isServiceEnabled();
    } catch (_) {
      _isAccessibilityEnabled = false;
    }
    notifyListeners();
  }
  
  Future<void> openAccessibilitySettings() async {
    await _bridge.openAccessibilitySettings();
  }
  
  /// Start listening for voice input (push-to-talk)
  Future<void> startListening() async {
    _state = AppState.listening;
    _statusMessage = 'Listening...';
    notifyListeners();
    
    final transcript = await _asr.listenOnce();
    if (transcript == null || transcript.isEmpty) {
      _state = AppState.idle;
      _statusMessage = 'No speech detected. Try again.';
      notifyListeners();
      return;
    }
    
    await _processUtterance(transcript);
  }
  
  Future<void> _processUtterance(String utterance) async {
    _statusMessage = 'Understanding: "$utterance"';
    notifyListeners();
    final lower = utterance.toLowerCase();
    if (lower.startsWith('teach') || lower.contains('teach me')) {
      await _startTeaching(utterance, utterance);
      return;
    }
    try {
      final local = LocalIntentModel();
      final parsed = await local.parse(utterance);
      if (parsed.isUnknown) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = "I don't have a learned workflow for that task. Would you like to teach me?";
        _statusMessage = _clarificationQuestion!;
        notifyListeners();
        return;
      }
      await _startCommand(utterance, parsed.slots);
    } catch (_) {
      try {
        final classification = await _llm.classifyIntent(utterance);
        switch (classification.intent) {
          case 'teach':
            await _startTeaching(utterance, classification.taskDescription ?? utterance);
            break;
          case 'command':
            await _startCommand(utterance, classification.extractedSlots);
            break;
          default:
            _state = AppState.idle;
            _statusMessage = 'I didn\'t understand that. Try saying "teach me to..." or "order..."';
            notifyListeners();
        }
      } catch (e) {
        _state = AppState.error;
        _statusMessage = 'Error: $e';
        notifyListeners();
      }
    }
  }
  
  Future<void> _startTeaching(String utterance, String taskDescription) async {
    _state = AppState.teaching;
    _teachUtterance = utterance;
    _statusMessage = 'Recording your actions... Perform the task now.';
    _actionTrace = [];
    notifyListeners();
    
    // Start teach session via bridge
    final stream = _bridge.startTeachSession();
    stream.listen((events) {
      _actionTrace.addAll(events);
      _statusMessage = 'Recording... ${_actionTrace.length} actions captured';
      notifyListeners();
    });
  }
  
  Future<void> stopTeaching() async {
    _state = AppState.synthesizing;
    _statusMessage = 'Analyzing your actions...';
    notifyListeners();
    
    try {
      final finalTrace = await _bridge.stopTeachSession();
      _actionTrace.addAll(finalTrace);
      
      // Synthesize flow
      final flow = await _synthesizer.synthesize(_teachUtterance!, _actionTrace);
      _lastSynthesizedFlow = flow;
      
      // Save flow and embedding
      await _store.saveFlow(flow);
      final embedding = await _llm.embed(flow.triggerIntent);
      await _store.saveEmbedding(flow.flowId, embedding);
      await _store.loadEmbeddingsIntoMemory();
      _flows = await _store.getAllFlows();
      
      await _store.logSession(flowId: flow.flowId, sessionType: 'teach', status: 'success');
      
      _state = AppState.idle;
      _statusMessage = 'Flow saved: ${flow.triggerIntent}';
      notifyListeners();
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Error synthesizing flow: $e';
      notifyListeners();
    }
  }
  
  Future<void> _startCommand(String utterance, Map<String, dynamic> extractedSlots) async {
    _state = AppState.matching;
    _statusMessage = 'Finding matching flow...';
    notifyListeners();
    
    try {
      final result = await _matcher.match(utterance, extractedSlots: extractedSlots);
      
      if (result.needsClarification || result.flow == null) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = result.clarificationQuestion ?? 'I couldn\'t find a matching flow. Could you be more specific?';
        _statusMessage = _clarificationQuestion!;
        notifyListeners();
        return;
      }
      
      if (result.confidence < 0.4) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = 'I found "${result.flow!.triggerIntent}" but I\'m not very confident. Should I proceed?';
        _statusMessage = _clarificationQuestion!;
        notifyListeners();
        return;
      }
      
      await _executeFlow(result.flow!, result.resolvedSlots);
    } catch (e) {
      _state = AppState.error;
      _statusMessage = 'Error: $e';
      notifyListeners();
    }
  }
  
  Future<void> _executeFlow(Flow flow, Map<String, dynamic> slotValues) async {
    _state = AppState.executing;
    notifyListeners();
    
    _replaySubscription = _replay.stateStream.listen((replayState) {
      _replayState = replayState;
      _statusMessage = replayState.message ?? 'Executing...';
      
      if (replayState.status == ReplayStatus.waitingForUser) {
        _state = AppState.waitingForClarification;
        _clarificationQuestion = replayState.clarificationQuestion;
      }
      
      notifyListeners();
    });
    
    final result = await _replay.execute(flow, slotValues);
    _replaySubscription?.cancel();
    
    await _store.logSession(
      flowId: flow.flowId,
      sessionType: 'replay',
      status: result.status == ReplayStatus.completed ? 'success' : 'failed',
      details: result.message,
    );
    
    _state = AppState.idle;
    _statusMessage = result.message ?? 'Done';
    _replayState = null;
    notifyListeners();
  }
  
  void stopExecution() {
    _replay.stop();
    _state = AppState.idle;
    _statusMessage = 'Execution stopped';
    _replayState = null;
    notifyListeners();
  }
  
  Future<void> provideClarification(String response) async {
    _clarification.provideResponse(response);
    _clarificationQuestion = null;
    _state = AppState.executing;
    _statusMessage = 'Continuing...';
    notifyListeners();
  }
  
  Future<void> deleteFlow(String flowId) async {
    await _store.deleteFlow(flowId);
    _flows = await _store.getAllFlows();
    notifyListeners();
  }
  
  void updateLlmConfig({String? endpoint, String? apiKey}) {
    _llm.updateConfig(endpoint: endpoint, apiKey: apiKey);
  }
  
  @override
  void dispose() {
    _replaySubscription?.cancel();
    _replay.dispose();
    super.dispose();
  }
}
