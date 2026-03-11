/// System prompt — short and simple for small models.
const llmSystemPrompt = 'You write short riddles for kids.';

/// Buduje prompt użytkownika dla danego tematu.
String buildRiddlePrompt(String topicName) =>
    'Write a short riddle about $topicName. Include the answer.';
