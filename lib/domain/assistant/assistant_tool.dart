import '../insights/logged_fact.dart';
import 'ai_provider.dart';
import 'tool_args.dart';

/// What the user said and when, handed to every tool run.
class ToolContext {
  const ToolContext({required this.userText, required this.now});

  final String userText;
  final DateTime now;
}

enum ToolStatus { done, failed, question, confirm }

/// The result of running one tool. [spoken] is a short first-person
/// sentence; [label] is the line shown on the result card.
class ToolOutcome {
  const ToolOutcome._({
    required this.status,
    required this.spoken,
    this.label,
    this.undo,
    this.onConfirm,
    this.isInfo = false,
    this.fact,
  });

  /// A write that happened. Shown as a result card; [undo] reverses it.
  factory ToolOutcome.done({
    required String label,
    required String spoken,
    Future<void> Function()? undo,
    LoggedFact? fact,
  }) => ToolOutcome._(
    status: ToolStatus.done,
    spoken: spoken,
    label: label,
    undo: undo,
    fact: fact,
  );

  /// A read-only answer. Shown as plain text, no card.
  factory ToolOutcome.info(String text) =>
      ToolOutcome._(status: ToolStatus.done, spoken: text, isInfo: true);

  factory ToolOutcome.failed(String message) =>
      ToolOutcome._(status: ToolStatus.failed, spoken: message);

  /// A short follow-up question; nothing was changed.
  factory ToolOutcome.question(String question) =>
      ToolOutcome._(status: ToolStatus.question, spoken: question);

  /// Nothing has happened yet; [onConfirm] performs the action once the
  /// user agrees. [label] describes it on the confirmation card.
  factory ToolOutcome.confirm({
    required String label,
    required String question,
    required Future<ToolOutcome> Function() onConfirm,
  }) => ToolOutcome._(
    status: ToolStatus.confirm,
    spoken: question,
    label: label,
    onConfirm: onConfirm,
  );

  final ToolStatus status;
  final String spoken;
  final String? label;
  final Future<void> Function()? undo;
  final Future<ToolOutcome> Function()? onConfirm;
  final bool isInfo;

  /// For a recorded life moment: what was logged, so advice can use it.
  final LoggedFact? fact;

  bool get isWrite => status == ToolStatus.done && !isInfo;
}

abstract class AssistantTool {
  const AssistantTool();

  String get name;
  String get description;

  /// Compact JSON schema of the arguments.
  Map<String, dynamic> get parameters;

  Future<ToolOutcome> run(ToolArgs args, ToolContext context);

  AiToolSpec get spec =>
      AiToolSpec(name: name, description: description, parameters: parameters);
}

/// What a destructive tool intends to do, shown before it happens.
class DestructivePlan {
  const DestructivePlan({
    required this.label,
    required this.question,
    required this.perform,
  });

  final String label;
  final String question;
  final Future<ToolOutcome> Function() perform;
}

/// A tool that deletes something. It can only ever *plan*: running it
/// always produces a confirmation, never the deletion itself.
abstract class DestructiveTool extends AssistantTool {
  const DestructiveTool();

  Future<DestructivePlan> plan(ToolArgs args, ToolContext context);

  @override
  Future<ToolOutcome> run(ToolArgs args, ToolContext context) async {
    final p = await plan(args, context);
    return ToolOutcome.confirm(
      label: p.label,
      question: p.question,
      onConfirm: p.perform,
    );
  }
}

/// Looks tools up by name and runs them without ever throwing.
class ToolRegistry {
  ToolRegistry(Iterable<AssistantTool> tools)
    : _tools = {for (final t in tools) t.name: t};

  final Map<String, AssistantTool> _tools;

  List<AiToolSpec> get specs => [for (final t in _tools.values) t.spec];

  AssistantTool? operator [](String name) => _tools[name];

  Future<ToolOutcome> execute(AiToolCall call, ToolContext context) async {
    final tool = _tools[call.name];
    if (tool == null) {
      return ToolOutcome.failed('I can\'t do that one yet.');
    }
    if (call.argumentsError != null) {
      return ToolOutcome.failed(
        'I didn\'t quite get that. Could you say it again?',
      );
    }
    try {
      return await tool.run(ToolArgs(call.arguments), context);
    } on ToolArgException catch (e) {
      return ToolOutcome.failed(e.message);
    } on ToolFollowUp catch (e) {
      return ToolOutcome.question(e.question);
    } catch (_) {
      return ToolOutcome.failed(
        'Something went wrong on my side. Please try that again.',
      );
    }
  }
}
