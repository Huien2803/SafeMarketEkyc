/// Bình luận công khai trên trang chi tiết sản phẩm (realtime qua Firebase).
class ProductComment {
  const ProductComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
    this.parentId,
    this.parentUserName,
    this.mine = false,
  });

  final String id;
  final int userId;
  final String userName;
  final String body;
  final DateTime createdAt;

  /// Nếu là phản hồi cho một bình luận khác, đây là id bình luận gốc.
  final String? parentId;
  final String? parentUserName;
  final bool mine;

  bool get isReply => parentId != null && parentId!.isNotEmpty;

  factory ProductComment.fromFirebase(
    String id,
    Map<dynamic, dynamic> data,
    int myUserId,
  ) {
    final uid = (data['userId'] as num?)?.toInt() ?? 0;
    return ProductComment(
      id: id,
      userId: uid,
      userName: data['userName']?.toString() ?? 'Người dùng',
      body: data['body']?.toString() ?? '',
      createdAt: _parseTime(data['createdAt']),
      parentId: (data['parentId']?.toString().isNotEmpty ?? false)
          ? data['parentId'].toString()
          : null,
      parentUserName: data['parentUserName']?.toString(),
      mine: uid != 0 && uid == myUserId,
    );
  }

  static DateTime _parseTime(dynamic v) {
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    return DateTime.now();
  }
}
