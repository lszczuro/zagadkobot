class LlmStats {
  const LlmStats({
    required this.ttft,
    required this.totalTime,
    required this.tokenCount,
  });

  final Duration ttft;
  final Duration totalTime;
  final int tokenCount;

  double get tokensPerSecond =>
      totalTime.inMilliseconds > 0 ? tokenCount / totalTime.inSeconds : 0;
}
