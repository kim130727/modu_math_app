enum TutorMessageRole {
  tutor,
  student,
}

enum TutorReplyType {
  greeting,
  hint,
  question,
  correct,
  retry,
}

class TutorMessage {
  const TutorMessage({
    required this.role,
    required this.text,
    required this.createdAt,
    this.replyType,
  });

  final TutorMessageRole role;
  final String text;
  final DateTime createdAt;
  final TutorReplyType? replyType;

  bool get isTutor => role == TutorMessageRole.tutor;
}
