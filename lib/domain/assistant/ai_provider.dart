/// Provider-neutral types for the assistant's language model.
library;

enum AiRole { system, user, assistant }

class AiMessage {
  const AiMessage(this.role, this.content);

  final AiRole role;
  final String content;
}

/// A tool the model may call. [parameters] is a compact JSON schema.
class AiToolSpec {
  const AiToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;
}

/// A tool call requested by the model. [arguments] is already decoded;
/// [argumentsError] is set when the model produced arguments that were not
/// valid JSON, so the engine can fail politely instead of crashing.
class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
    this.argumentsError,
  });

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final String? argumentsError;
}

class AiResponse {
  const AiResponse({this.text, this.toolCalls = const []});

  final String? text;
  final List<AiToolCall> toolCalls;
}

enum AiFailureKind {
  notConfigured,
  rateLimited,
  unauthorized,
  badRequest,
  server,
  network,
  badResponse,
}

/// Thrown by an [AiProvider]. [message] is always safe to show the user.
class AiProviderException implements Exception {
  const AiProviderException(this.kind, this.message);

  final AiFailureKind kind;
  final String message;

  @override
  String toString() => 'AiProviderException($kind): $message';
}

/// A chat model that may answer with text, tool calls, or both.
abstract class AiProvider {
  /// False when no API key is available; [chat] then throws
  /// [AiFailureKind.notConfigured].
  bool get isConfigured;

  Future<AiResponse> chat({
    required List<AiMessage> messages,
    required List<AiToolSpec> tools,
  });
}
