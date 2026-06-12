import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/auth_service.dart';
class ProductService {
  ProductService._();
  static final ProductService instance = ProductService._();

  /// NestJS trả `[...]`; một số bản cũ trả `{ items: [...] }`.
  List<dynamic> _parseListResponse(String body, String label) {
    final decoded = jsonDecode(body);
    if (decoded is List<dynamic>) return decoded;
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List<dynamic>) return items;
      final msg = decoded['message'];
      final text = msg is List
          ? msg.join(', ')
          : (msg is String ? msg : 'Phản hồi không hợp lệ từ $label');
      throw Exception(text);
    }
    throw Exception('Không đọc được dữ liệu $label');
  }

  Future<List<ProductCategory>> getCategories() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/categories');
    final res = await http.get(uri).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      throw Exception('Không tải danh mục (${res.statusCode})');
    }
    final list = _parseListResponse(res.body, 'danh mục');
    return list
        .map((e) => ProductCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductListItem>> getProducts({
    int? categoryId,
    String? search,
    bool verifiedOnly = false,
  }) async {
    final query = <String, String>{};
    if (categoryId != null && categoryId > 0) {
      query['categoryId'] = '$categoryId';
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (verifiedOnly) {
      query['verifiedOnly'] = 'true';
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/products')
        .replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri).timeout(ApiConfig.timeout);
    if (res.statusCode != 200) {
      throw Exception('Không tải được sản phẩm (${res.statusCode})');
    }
    final list = _parseListResponse(res.body, 'sản phẩm');
    return list
        .map((e) => ProductListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ProductDetail> getProductDetail(int id) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$id');
    final res = await http.get(uri).timeout(ApiConfig.timeout);
    if (res.statusCode == 404) {
      throw Exception('Sản phẩm không tồn tại');
    }
    if (res.statusCode != 200) {
      throw Exception('Lỗi tải chi tiết (${res.statusCode})');
    }
    return ProductDetail.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  /// Đăng bán sản phẩm — ảnh bắt buộc (multipart).
  Future<ProductDetail> createProduct({
    required XFile image,
    required String title,
    required String description,
    required int price,
    required int conditionPct,
    required String location,
    required int categoryId,
  }) async {
    final token = AuthService.instance.accessToken;
    if (token == null) {
      throw Exception('Bạn cần đăng nhập để đăng bán');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/products');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['price'] = '$price'
      ..fields['conditionPct'] = '$conditionPct'
      ..fields['location'] = location
      ..fields['categoryId'] = '$categoryId';

    req.files.add(await _imagePart(image));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    final body = res.body.isNotEmpty
        ? jsonDecode(res.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ProductDetail.fromJson(body);
    }
    throw Exception(body['message'] ?? 'Không đăng được sản phẩm');
  }

  Future<void> updateProduct(
    int id, {
    String? title,
    String? description,
    int? price,
    int? conditionPct,
    String? location,
    int? categoryId,
  }) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập');

    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$id');
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (price != null) body['price'] = price;
    if (conditionPct != null) body['conditionPct'] = conditionPct;
    if (location != null) body['location'] = location;
    if (categoryId != null) body['categoryId'] = categoryId;

    final res = await http
        .put(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['message'] ?? 'Không cập nhật được sản phẩm');
    }
  }

  Future<void> hideProduct(int id) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập');
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$id/hide');
    final res = await http.post(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không ẩn được sản phẩm');
    }
  }

  Future<void> deleteProduct(int id) async {
    final token = AuthService.instance.accessToken;
    if (token == null) throw Exception('Cần đăng nhập');
    final uri = Uri.parse('${ApiConfig.baseUrl}/products/$id');
    final res = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(ApiConfig.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('Không xóa được sản phẩm');
    }
  }

  Future<http.MultipartFile> _imagePart(XFile file) async {
    final name = file.name.isNotEmpty ? file.name : 'product.jpg';
    final lower = name.toLowerCase();
    MediaType mime;
    if (lower.endsWith('.png')) {
      mime = MediaType('image', 'png');
    } else if (lower.endsWith('.webp')) {
      mime = MediaType('image', 'webp');
    } else {
      mime = MediaType('image', 'jpeg');
    }

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: name,
        contentType: mime,
      );
    }
    return http.MultipartFile.fromPath(
      'image',
      file.path,
      filename: name,
      contentType: mime,
    );
  }
}
