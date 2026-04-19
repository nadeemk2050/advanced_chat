import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/mission_model.dart';
import '../models/chat_models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIService {
  // The user should ideally set this in the UI or an environment variable.
  // For now, I'll provide a placeholder.
  String _apiKey = ''; 

  void setApiKey(String key) => _apiKey = key;
  bool get hasKey => _apiKey.isNotEmpty;

  GenerativeModel? get _model {
    if (_apiKey.isEmpty) return null;
    return GenerativeModel(model: 'gemini-1.5-flash', apiKey: _apiKey);
  }

  // 1. AI PREDICTIVE DEADLINES
  // Analyzes the task title and the selected deadline against historical completion times
  Future<String?> checkDeadlineFeasibility(String taskTitle, DateTime deadline, List<MissionTask> history) async {
    if (_model == null) return null;

    final histSummary = history.take(10).map((t) => "- ${t.title} (Completed: ${t.isCompleted})").join('\n');
    
    final prompt = '''
      You are a Digital Chief of Staff. A user is setting a deadline for a new task.
      Task: "$taskTitle"
      Deadline: ${deadline.toIso8601String()}
      Current Time: ${DateTime.now().toIso8601String()}
      
      User's recent task history:
      $histSummary
      
      Does this deadline seem realistic? If it seems too tight or historically unlikely to be finished on time, 
      provide a BRIEF 1-sentence warning (max 15 words) starting with "⚠️ AI WARNING:". 
      If it looks okay, return "OK".
    ''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "OK";
      return text == "OK" ? null : text;
    } catch (e) {
      return null;
    }
  }

  // 2. NLP: SUGGEST TASKS FROM CHAT
  // Analyzes last N messages and suggests potential tasks
  Future<List<String>> suggestTasksFromChat(List<MessageModel> messages) async {
    if (_model == null) return [];

    final chatText = messages.reversed.take(20).map((m) => "${m.senderId}: ${m.text}").join('\n');
    
    final prompt = '''
      Analyze the following chat conversation and identify if there are any actionable tasks mentioned.
      Return ONLY a list of tasks, one per line, concise (max 8 words each).
      If no tasks are found, return "NONE".
      
      CHAT HISTORY:
      $chatText
    ''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text?.trim() ?? "NONE";
      if (text == "NONE") return [];
      return text.split('\n').where((s) => s.isNotEmpty).map((s) => s.replaceAll(RegExp(r'^[-*•\d.]+\s*'), '')).toList();
    } catch (e) {
      return [];
    }
  }
}
