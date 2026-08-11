import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/aquarium_model.dart';

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
        'flag a temperature outside 24-27°C for tropical community tanks). '
        'If you are not confident about a diagnosis, say so and recommend '
        'a water test or manual inspection rather than guessing.',
      ),
    );
  }

  void startNewSession() {
    _session = _model.startChat();
  }

  /// Sends [userMessage] along with a compact snapshot of current
  /// aquarium telemetry so the model's advice is grounded in reality,
  /// not just the user's raw text.
  Future<String> sendMessage(
    String userMessage, {
    AquariumModel? context,
  }) async {
    _session ??= _model.startChat();

    final contextLine = context == null
        ? ''
        : '\n\n[Live telemetry — name: ${context.name}, '
            'temperature: ${context.temperatureC}°C, '
            'status: ${context.status}, '
            'hub online: ${context.hubOnline}, '
            'last fed: ${context.lastFedAt ?? "unknown"}]';

    final response = await _session!.sendMessage(
      Content.text('$userMessage$contextLine'),
    );

    return response.text ??
        'Sorry, I could not generate a response. Please try rephrasing.';
  }
}
