import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/auth_service.dart';
import 'package:safemarket_app/services/product_service.dart';

/// Đăng bán sản phẩm — ảnh bắt buộc.
class PostProductScreen extends StatefulWidget {
  const PostProductScreen({super.key});

  @override
  State<PostProductScreen> createState() => _PostProductScreenState();
}

class _PostProductScreenState extends State<PostProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();

  XFile? _image;
  Uint8List? _imagePreview;
  List<ProductCategory> _categories = [];
  int? _categoryId;
  double _condition = 85;
  bool _loading = false;
  bool _loadingCats = true;

  @override
  void initState() {
    super.initState();
    _locationCtrl.text = 'Quận 1, TP.HCM';
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ProductService.instance.getCategories();
      if (mounted) {
        setState(() {
          _categories = cats;
          _categoryId = cats.isNotEmpty ? cats.first.categoryId : null;
          _loadingCats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _image = file;
      _imagePreview = bytes;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ảnh sản phẩm (bắt buộc)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn danh mục sản phẩm')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ProductService.instance.createProduct(
        image: _image!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: int.parse(_priceCtrl.text.replaceAll('.', '').replaceAll(',', '')),
        conditionPct: _condition.round(),
        location: _locationCtrl.text.trim(),
        categoryId: _categoryId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đăng bán thành công!'),
          backgroundColor: AppColors.trustGreen,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đăng bán sản phẩm'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: _loadingCats
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Ảnh sản phẩm *',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Người mua cần thấy hình dạng sản phẩm trước khi mua.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showImageSourceSheet,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _image == null
                                ? AppColors.primary
                                : AppColors.textMuted.withValues(alpha: 0.3),
                            width: _image == null ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _imagePreview == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined,
                                      size: 48, color: AppColors.primary),
                                  SizedBox(height: 8),
                                  Text(
                                    'Chạm để thêm ảnh (bắt buộc)',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    _imagePreview!,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: FilledButton.icon(
                                      onPressed: _showImageSourceSheet,
                                      icon: const Icon(Icons.edit, size: 18),
                                      label: const Text('Đổi ảnh'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề *',
                        hintText: 'VD: iPhone 13 Pro Max 256GB',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập tiêu đề' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        hintText: 'Tình trạng, phụ kiện kèm theo...',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Giá (VNĐ) *',
                        hintText: '15500000',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Nhập giá';
                        if (int.tryParse(v) == null || int.parse(v) <= 0) {
                          return 'Giá không hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tình trạng: ${_condition.round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _condition,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      label: '${_condition.round()}%',
                      onChanged: (v) => setState(() => _condition = v),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _categoryId,
                      decoration: const InputDecoration(
                        labelText: 'Danh mục *',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.categoryId,
                              child: Text(c.name),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Khu vực *',
                        hintText: 'Quận 1, TP.HCM',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập khu vực' : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Đăng bán ngay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
