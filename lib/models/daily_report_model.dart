class DailyReportModel {
  final String id;
  final String subject;
  final String body;
  final String createdById;
  final String createdByName;
  final DateTime? issuedAt;
  final DateTime? createdAt;
  final String pdfPath;

  const DailyReportModel({
    required this.id,
    required this.subject,
    required this.body,
    required this.createdById,
    required this.createdByName,
    required this.issuedAt,
    required this.createdAt,
    required this.pdfPath,
  });

  factory DailyReportModel.fromJson(Map<String, dynamic> json) {
    return DailyReportModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      createdById: (json['createdBy'] ?? '').toString(),
      createdByName: (json['createdByName'] ?? '').toString(),
      issuedAt: json['issuedAt'] != null
          ? DateTime.tryParse(json['issuedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      pdfPath: (json['pdfPath'] ?? '').toString(),
    );
  }
}
