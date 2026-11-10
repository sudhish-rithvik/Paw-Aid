// lib/services/ai/gemini_triage_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import 'animal_triage_model.dart';
import 'animal_triage_service.dart';

/// Gemini Vision Animal Triage Service
/// Uses Google Gemini 2.0 Flash (Free Tier via Google AI Studio).
/// Provides state-of-the-art multimodal vision triage for species, fractures,
/// bleeding, trauma, and urgency scoring without paid cloud infrastructure.
class GeminiTriageService implements AnimalTriageService {
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  const GeminiTriageService();

  @override
  Future<bool> isModelAvailable() async => AppConfig.isGeminiConfigured;

  bool get isAvailable => AppConfig.isGeminiConfigured;

  @override
  String get modelContractDocumentation => '''
Google Gemini 2.0 Flash Vision Contract:
- Endpoint: $_endpoint
- Input: Multimodal Image (JPEG/PNG bytes) + Emergency Rescue Prompt
- Output: Structured JSON conforming to AnimalTriageResult schema
- Cost: \$0.00 (Google AI Studio Free Tier: 15 RPM, 1,500 RPD)
''';

  @override
  Future<AnimalTriageResult> analyzeImage({
    required String imagePath,
    required String reportId,
    String? userNotes,
    String? selectedAnimalType,
  }) async {
    final apiKey = AppConfig.geminiApiKey.trim();
    if (apiKey.isEmpty || !AppConfig.isGeminiConfigured) {
      throw StateError('GEMINI_API_KEY is not configured in AppConfig.');
    }

    final imageFile = File(imagePath);
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found for Gemini analysis', imagePath);
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = imagePath.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    final promptText = '''
You are an expert veterinary emergency rescue vision assistant for PAW-AID.
Analyze this photo of an animal in distress.

Context provided by citizen:
- Selected Species: ${selectedAnimalType ?? 'Unknown'}
- Citizen Notes: ${userNotes ?? 'None provided'}

Perform visual triage. Respond ONLY with a valid JSON object matching this exact schema:
{
  "animal": "Dog | Cat | Cow | Bird | Other",
  "species_detail": "Specific breed or species description if identifiable",
  "confidence": 0.94,
  "visible_injuries": ["list of observable physical injuries, lesions, emaciation, fracture signs, or trauma"],
  "injury_category": "FRACTURE_TRAUMA | OPEN_WOUND | MALNUTRITION_EMACIATION | SKIN_DISEASE | HEAD_TRAUMA | GENERAL_DISTRESS",
  "mobility": "Immobilized | Severely Impaired | Mildly Impaired | Normal",
  "pain_level": "Severe | Moderate | Mild | Non-apparent",
  "severity": "CRITICAL | HIGH | MEDIUM | LOW",
  "urgency_score": 8,
  "recommended_action": "Concise guidance for volunteer rescuers and first-aid shelter staff",
  "reason": "Clear objective visual observation explaining the triage rationale"
}

Important Rules:
1. Do not invent injuries not visible or supported by signs.
2. AI-generated severity is preliminary emergency triage for dispatch prioritization, NOT a final veterinary diagnosis.
''';

    final uri = Uri.parse('$_endpoint?key=$apiKey');
    final requestBody = jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': promptText},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.1,
      }
    });

    debugPrint('[GeminiTriageService] Calling Gemini 2.0 Flash for report: $reportId...');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(const Duration(seconds: 12));

    if (response.statusCode != 200) {
      throw HttpException(
        'Gemini API returned status ${response.statusCode}: ${response.body}',
        uri: uri,
      );
    }

    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini returned empty candidates.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = parts?.first?['text'] as String?;
    if (text == null || text.isEmpty) {
      throw const FormatException('Gemini returned empty text response.');
    }

    final parsedData = jsonDecode(text) as Map<String, dynamic>;
    debugPrint('[GeminiTriageService] Triage completed: ${parsedData['animal']} - ${parsedData['severity']}');

    final injuriesRaw = parsedData['visible_injuries'];
    final List<String> injuries = injuriesRaw is List
        ? injuriesRaw.map((e) => e.toString()).toList()
        : [parsedData['injury_category']?.toString() ?? 'Physical distress observable'];

    final sev = (parsedData['severity'] as String? ?? 'HIGH').toLowerCase();
    final confidence = (parsedData['confidence'] as num?)?.toDouble() ?? 0.92;
    final score = (parsedData['urgency_score'] as num?)?.toInt() ?? 7;

    return AnimalTriageResult(
      reportId: reportId,
      modelId: 'google.gemini-2.0-flash',
      animal: parsedData['animal'] as String? ?? selectedAnimalType ?? 'Dog',
      confidence: confidence,
      visibleInjuries: injuries,
      mobility: parsedData['mobility'] as String? ?? 'Impaired',
      painLevel: parsedData['pain_level'] as String? ?? 'Moderate',
      severity: sev,
      urgencyScore: score,
      recommendedAction: parsedData['recommended_action'] as String? ??
          'Dispatch nearest rescue unit with appropriate containment.',
      reason: parsedData['reason'] as String? ??
          'Visual analysis via Gemini 2.0 Flash multimodal assessment.',
      status: AIAnalysisStatus.completed,
      analyzedAt: DateTime.now(),
    );
  }
}
