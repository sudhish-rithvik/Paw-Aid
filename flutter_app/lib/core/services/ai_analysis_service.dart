// lib/core/services/ai_analysis_service.dart
import '../../services/ai/animal_triage_service.dart';
import '../../services/ai/hybrid_animal_triage_service.dart';

/// AI Analysis Service
/// Provides veterinary vision triage, injury classification, and severity scoring.
/// Uses Option 3 Hybrid Architecture: Gemini 2.0 Flash (Online) + LiteRT/Local (Offline Fallback).
class AIAnalysisService {
  AIAnalysisService._();

  static const AnimalTriageService _triageService = HybridAnimalTriageService();

  /// Trigger AI analysis for an animal distress report
  static Future<Map<String, dynamic>> triggerAIAnalysis(
    String reportId, {
    String? imagePath,
    String? notes,
    String? animalType,
  }) async {
    final result = await _triageService.analyzeImage(
      imagePath: imagePath ?? '',
      reportId: reportId,
      userNotes: notes,
      selectedAnimalType: animalType,
    );
    return result.toMap();
  }

  /// Get detailed AI analysis results for an existing case
  static Future<Map<String, dynamic>> getAIAnalysis(
    String reportId, {
    String? animalType,
    String? notes,
  }) async {
    final result = await _triageService.analyzeImage(
      imagePath: '',
      reportId: reportId,
      userNotes: notes,
      selectedAnimalType: animalType,
    );
    return result.toMap();
  }

  /// Check if a compiled on-device .tflite model is available
  static Future<bool> isLocalModelAvailable() => _triageService.isModelAvailable();

  /// Documentation of the input/output contract for LiteRT / TFLite
  static String get modelContract => _triageService.modelContractDocumentation;
}
