import 'package:get/get.dart';

import '../../data/assistant/chat_history_store.dart';
import '../../data/assistant/groq_provider.dart';
import '../../data/assistant/remote_memory_store.dart';
import '../../domain/assistant/ai_provider.dart';
import '../../domain/assistant/assistant_engine.dart';
import '../../domain/assistant/assistant_tool.dart';
import '../../domain/assistant/memory_store.dart';
import '../../presentation/assistant/assistant_tool_deps.dart';
import '../../presentation/assistant/assistant_tools.dart';
import '../../presentation/assistant/voice_service.dart';
import '../../presentation/controllers/assistant_controller.dart';
import '../config/assistant_config.dart';

/// Registers the assistant stack. Idempotent and lazy: nothing is built,
/// no network is touched and no microphone permission is requested until
/// the user opens the assistant.
void registerAssistantDependencies({AssistantConfig? config}) {
  if (!Get.isRegistered<AssistantConfig>()) {
    Get.put<AssistantConfig>(
      config ?? AssistantConfig.fromEnvironment(),
      permanent: true,
    );
  }
  if (!Get.isRegistered<AiProvider>()) {
    Get.lazyPut<AiProvider>(() {
      final cfg = Get.find<AssistantConfig>();
      return GroqProvider(apiKey: cfg.groqApiKey, model: cfg.model);
    }, fenix: true);
  }
  if (!Get.isRegistered<MemoryStore>()) {
    Get.lazyPut<MemoryStore>(() {
      final cfg = Get.find<AssistantConfig>();
      return cfg.hasRemoteMemory
          ? RemoteMemoryStore(cfg.memoryUrl)
          : const NoopMemoryStore();
    }, fenix: true);
  }
  if (!Get.isRegistered<ChatHistoryStore>()) {
    Get.lazyPut<ChatHistoryStore>(
      () => SharedPrefsChatHistoryStore(),
      fenix: true,
    );
  }
  if (!Get.isRegistered<VoiceService>()) {
    Get.lazyPut<VoiceService>(() => DeviceVoiceService(), fenix: true);
  }
  if (!Get.isRegistered<AssistantEngine>()) {
    Get.lazyPut<AssistantEngine>(
      () => AssistantEngine(
        provider: Get.find<AiProvider>(),
        tools: ToolRegistry(buildAssistantTools(AssistantToolDeps())),
      ),
      fenix: true,
    );
  }
  if (!Get.isRegistered<AssistantController>()) {
    Get.lazyPut<AssistantController>(() => AssistantController(), fenix: true);
  }
}
