/// Build-time configuration for the assistant.
///
/// Values come from `--dart-define` / `--dart-define-from-file=.env` and are
/// never committed. See docs/assistant.md.
class AssistantConfig {
  const AssistantConfig({
    this.groqApiKey = '',
    this.memoryUrl = '',
    this.model = 'llama-3.3-70b-versatile',
  });

  /// Reads the compile-time defines.
  factory AssistantConfig.fromEnvironment() {
    const model = String.fromEnvironment('GROQ_MODEL');
    return AssistantConfig(
      groqApiKey: const String.fromEnvironment('GROQ_API_KEY'),
      memoryUrl: const String.fromEnvironment('AI_MEMORY_URL'),
      // An empty define (as in .env.example) means "use the default".
      model: model.trim().isEmpty ? defaultModel : model.trim(),
    );
  }

  static const defaultModel = 'llama-3.3-70b-versatile';

  final String groqApiKey;

  /// Optional remote memory endpoint; empty means memory stays on-device.
  final String memoryUrl;
  final String model;

  bool get isConfigured => groqApiKey.trim().isNotEmpty;
  bool get hasRemoteMemory => memoryUrl.trim().isNotEmpty;
}
