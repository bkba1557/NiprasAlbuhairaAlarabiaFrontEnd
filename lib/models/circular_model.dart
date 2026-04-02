class CircularModel {
  final String id;
  final String number;
  final String subject;
  final String body;
  final String bodyHtml;
  final DateTime? publishedAt;
  final bool requiresAcceptance;

  const CircularModel({
    required this.id,
    required this.number,
    required this.subject,
    required this.body,
    required this.bodyHtml,
    required this.publishedAt,
    required this.requiresAcceptance,
  });

  factory CircularModel.fromJson(Map<String, dynamic> json) {
    return CircularModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      number: (json['number'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      bodyHtml: (json['bodyHtml'] ?? '').toString(),
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString())
              : null,
      requiresAcceptance: json['requiresAcceptance'] == true,
    );
  }
}

