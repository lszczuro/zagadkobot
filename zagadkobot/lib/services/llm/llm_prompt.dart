/// System prompt — English for Qwen.
const llmSystemPrompt =
    'You are a riddle writer for children. Write short, fun riddles.'
    'Always end with "ANSWER:" followed by the answer on the same line.';

/// Buduje prompt użytkownika dla danego tematu.
String buildRiddlePrompt(String topicName) =>
    'Write a short riddle for children about: $topicName. '
    'End with "ANSWER:" and the answer.';
