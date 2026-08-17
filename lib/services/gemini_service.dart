import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/aquarium_model.dart';
import '../models/aquarium_ai_analysis.dart';
import '../models/feeding_log_model.dart';

/// Wraps the google_generative_ai SDK. The system instruction grounds
/// every answer in the aquarium's real live telemetry (temperature,
/// status, last feed time) so the assistant gives context-aware
/// troubleshooting instead of generic chatbot answers.
class GeminiService {
  final String apiKey;
  late final GenerativeModel _model;
  ChatSession? _session;

  GeminiService({required this.apiKey}) {
    // Google retires dated model versions on short notice (2.5-flash was
    // cut off for new API keys in early Aug 2026, ahead of its official
    // Oct 2026 shutdown). gemini-3.6-flash is the current default as of
    // Aug 2026. If this 404s again in the future, check
    // https://ai.google.dev/gemini-api/docs/models for the current name,
    // or switch to the rolling alias 'gemini-flash-latest' which Google
    // auto-updates (with 2 weeks' notice before breaking changes).
    _model = GenerativeModel(
      model: 'gemini-3.6-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(
        'You are Aqua AI, the in-app troubleshooting assistant for AquaNest, '
        'a smart aquarium monitoring app. Be concise, practical, and safety-'
        'aware. When telemetry is provided, reference it directly (e.g. '
        'flag a temperature outside 24-27°C for tropical community tanks, '
        'or a water level or pH that looks off). If you are not confident '
        'about a diagnosis, say so and recommend a water test or manual '
        'inspection rather than guessing.',
      ),
    );
  }

  void startNewSession() {
    _session = _model.startChat();
  }

  /// Sends [userMessage] along with a compact snapshot of current
  /// aquarium telemetry and recent feeding history so the model's
  /// advice is grounded in reality, not just the user's raw text. The
  /// user never has to type "my pH is 7.2" — it's already in context.
  Future<String> sendMessage(
    String userMessage, {
    AquariumModel? context,
    List<FeedingLogEntry>? feedingHistory,
  }) async {
    _session ??= _model.startChat();

    final contextLine =
        context == null ? '' : _buildContextBlock(context, feedingHistory);

    final response = await _session!.sendMessage(
      Content.text('$userMessage$contextLine'),
    );

    return response.text ??
        'Sorry, I could not generate a response. Please try rephrasing.';
  }

  String _buildContextBlock(
    AquariumModel c,
    List<FeedingLogEntry>? feedingHistory,
  ) {
    final buffer = StringBuffer()
      ..write('\n\n[Live telemetry — name: ${c.name}, '
          'temperature: ${c.temperatureC}°C, '
          'status: ${c.status}, '
          'hub online: ${c.hubOnline}, '
          'water level: ${c.waterLevel != null ? "${c.waterLevel!.toStringAsFixed(0)}%" : "unknown"}, '
          'pH: ${c.phLevel?.toStringAsFixed(1) ?? "unknown"}, '
          'food level: ${c.foodLevel != null ? "${c.foodLevel!.toStringAsFixed(0)}%" : "unknown"}, '
          'missed feedings: ${c.missedFeedingsCount}, '
          'last fed: ${c.lastFedAt ?? "unknown"}]');

    if (feedingHistory != null && feedingHistory.isNotEmpty) {
      final recent = feedingHistory
          .take(5)
          .map((h) => '${h.feedAt.toIso8601String()} (${h.status}, ${h.source})')
          .join('; ');
      buffer.write('\n[Recent feeding history: $recent]');
    }

    return buffer.toString();
  }

  /// Sends one camera frame for a silent health read — used by
  /// CameraProvider's background monitoring timer, not the chat UI.
  /// Deliberately a one-off `generateContent` call (not part of the
  /// chat session): frame analyses shouldn't pollute the user-visible
  /// conversation history or its context window.
  Future<AquariumAiAnalysis> analyzeAquariumFrame(Uint8List imageBytes) async {
    final now = DateTime.now();
    try {
      final response = await _model.generateContent([
        Content.multi([
          TextPart(
            'You are looking at one frame from a live aquarium camera. '
            'Identify the visible fish species if possible, assess the '
            'activity level (low/normal/high), and flag any visible signs '
            'of disease, injury, or distress — e.g. fin rot, white spot/ich, '
            'unusual lethargy, gasping at the surface, visible lesions. '
            'Respond with ONLY raw JSON, no markdown fences, in exactly '
            'this shape: {"status":"healthy|warning|critical",'
            '"species":"short string","activityLevel":"low|normal|high",'
            '"summary":"one short sentence"}. '
            'Use "warning" for early or uncertain signs. Use "critical" '
            'only for a clear, visibly serious health emergency.',
          ),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final raw = (response.text ?? '').trim();
      final cleaned =
          raw.replaceAll(RegExp(r'^```json|```$', multiLine: true), '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final status = switch ((json['status'] as String? ?? '').toLowerCase()) {
        'critical' => AiHealthStatus.critical,
        'warning' => AiHealthStatus.warning,
        'healthy' => AiHealthStatus.healthy,
        // Model returned something we don't recognize — surface as a
        // warning (yellow) rather than silently defaulting to "healthy"
        // (falsely reassuring) or "critical" (falsely alarming).
        _ => AiHealthStatus.warning,
      };

      return AquariumAiAnalysis(
        status: status,
        analyzedAt: now,
        species: json['species'] as String?,
        activityLevel: json['activityLevel'] as String?,
        summary: json['summary'] as String?,
      );
    } catch (e) {
      // Malformed JSON, network hiccup, etc. — same reasoning as above:
      // fail to "warning", never to a falsely-clean "healthy" or a
      // falsely-alarming "critical" push notification.
      return AquariumAiAnalysis(
        status: AiHealthStatus.warning,
        analyzedAt: now,
        summary: 'AI health check failed this round — will retry shortly.',
      );
    }
  }
}
