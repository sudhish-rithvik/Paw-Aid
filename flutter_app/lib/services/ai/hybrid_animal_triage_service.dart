// lib/services/ai/hybrid_animal_triage_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import 'animal_triage_model.dart';
import 'animal_triage_service.dart';
import 'gemini_triage_service.dart';

/// Hybrid Animal Triage Service (Option 3 Architecture)
/// Combines the deep visual reasoning of Google Gemini 2.0 Flash (Online Free Tier)
/// with the 100% offline uptime of on-device LiteRT / heuristic mobile triage.
///
/// Guaranteed zero cloud billing, zero paid subscriptions, and zero downtime in dead zones.
class HybridAnimalTriageService implements AnimalTriageService {
  final GeminiTriageService _geminiService;
  final LocalAnimalTriageService _localService;

  const HybridAnimalTriageService({
    GeminiTriageService? geminiService,
    LocalAnimalTriageService? localService,
  })  : _geminiService = geminiService ?? const GeminiTriageService(),
        _localService = localService ?? const LocalAnimalTriageService();

  @override
  Future<bool> isModelAvailable() async {
    // Local fallback is always ready
    return true;
  }

  @override
  String get modelContractDocumentation => '''
PAW-AID Option 3: Hybrid Vision Triage Architecture
- Primary Tier (Online): Google Gemini 2.0 Flash via Google AI Studio Free Tier
  • Endpoint: https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent
  • Deep multimodal recognition of fractures, lacerations, skin disease, and species traits.
- Fallback Tier (Offline): On-Device LiteRT & Heuristic Mobile Engine
  • Engine: LocalAnimalTriageService
  • Model: assets/models/animal_triage.tflite (MobileNetV2 Quantized)
  • 100% offline emergency triage when in cellular dead zones or highway areas.

${_localService.modelContractDocumentation}
''';

  @override
  Future<AnimalTriageResult> analyzeImage({
    required String imagePath,
    required String reportId,
    String? userNotes,
    String? selectedAnimalType,
  }) async {
    // 1. Attempt Online Vision Triage via Gemini 2.0 Flash if configured
    if (AppConfig.isGeminiConfigured && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        try {
          debugPrint('[HybridAnimalTriageService] Attempting primary vision triage via Gemini 2.0 Flash...');
          final geminiResult = await _geminiService.analyzeImage(
            imagePath: imagePath,
            reportId: reportId,
            userNotes: userNotes,
            selectedAnimalType: selectedAnimalType,
          );
          return geminiResult;
        } catch (e) {
          debugPrint('[HybridAnimalTriageService] Gemini vision triage unavailable or timed out ($e). Seamlessly switching to on-device fallback.');
        }
      }
    } else if (!AppConfig.isGeminiConfigured) {
      debugPrint('[HybridAnimalTriageService] GEMINI_API_KEY not configured. Executing on-device LiteRT/local triage.');
    }

    // 2. Offline / Low-Signal Fallback: Execute on-device LiteRT / heuristic engine
    debugPrint('[HybridAnimalTriageService] Running on-device local triage for report: $reportId');
    final localResult = await _localService.analyzeImage(
      imagePath: imagePath,
      reportId: reportId,
      userNotes: userNotes,
      selectedAnimalType: selectedAnimalType,
    );

    return localResult;
  }
}
