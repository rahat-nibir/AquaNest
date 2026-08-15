/// The "traffic signal" read on tank health from a single analyzed
/// camera frame. `unknown` is the pre-first-analysis state, distinct
/// from `healthy` — a badge that says "healthy" before the AI has ever
/// actually looked at a frame would be lying.
enum AiHealthStatus { unknown, healthy, warning, critical }

/// Result of sending one camera frame to GeminiService for analysis.
class AquariumAiAnalysis {
  final AiHealthStatus status;
  final String? species;
  final String? activityLevel;
  final String? summary;
  final DateTime analyzedAt;

  AquariumAiAnalysis({
    required this.status,
    required this.analyzedAt,
    this.species,
    this.activityLevel,
    this.summary,
  });
}
