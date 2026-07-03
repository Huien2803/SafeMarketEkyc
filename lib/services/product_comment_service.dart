import 'package:firebase_database/firebase_database.dart';
import 'package:safemarket_app/models/product_comment.dart';
import 'package:safemarket_app/services/auth_service.dart';

/// Bình luận sản phẩm realtime qua Firebase Realtime Database.
///
/// Cấu trúc: safemarket/productComments/{productId}/{commentId}
class ProductCommentService {
  ProductCommentService._();
  static final ProductCommentService instance = ProductCommentService._();

  DatabaseReference _ref(int productId) => FirebaseDatabase.instance
      .ref()
      .child('safemarket')
      .child('productComments')
      .child('$productId');

  /// Stream danh sách bình luận của một sản phẩm (mới nhất ở cuối).
  Stream<List<ProductComment>> watch(int productId) {
    final myId = AuthService.instance.currentUser?.userId ?? 0;
    return _ref(productId).onValue.map((event) {
      final snap = event.snapshot;
      if (!snap.exists || snap.value == null) return <ProductComment>[];

      final map = Map<dynamic, dynamic>.from(snap.value as Map);
      final list = map.entries.map((e) {
        final data = Map<dynamic, dynamic>.from(e.value as Map);
        return ProductComment.fromFirebase(e.key.toString(), data, myId);
      }).toList();

      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  Future<void> add(
    int productId,
    String body, {
    String? parentId,
    String? parentUserName,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw Exception('Cần đăng nhập để bình luận');
    final text = body.trim();
    if (text.isEmpty) return;

    await _ref(productId).push().set({
      'userId': user.userId,
      'userName': user.displayName ?? user.email,
      'body': text,
      'parentId': parentId,
      'parentUserName': parentUserName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> delete(int productId, String commentId) async {
    await _ref(productId).child(commentId).remove();
  }
}
