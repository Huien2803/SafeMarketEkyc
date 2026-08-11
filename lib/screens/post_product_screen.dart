import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safemarket_app/core/theme/app_colors.dart';
import 'package:safemarket_app/models/product.dart';
import 'package:safemarket_app/services/api_config.dart';
import 'package:safemarket_app/services/product_service.dart';
import 'package:safemarket_app/utils/input_validators.dart';

/// Đăng bán / sửa tin sản phẩm — ảnh bắt buộc khi đăng mới.
class PostProductScreen extends StatefulWidget {
  const PostProductScreen({super.key, this.editProductId});

  /// Nếu có: chế độ sửa tin (PUT metadata, giữ ảnh cũ).
  final int? editProductId;

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

  static const int _maxImages = 8;
  final List<XFile> _images = [];
  final List<Uint8List> _previews = [];
  List<ProductCategory> _categories = [];
  int? _categoryId;
  double _condition = 85;
  bool _loading = false;
  bool _loadingCats = true;
  bool _loadingEdit = false;
  String? _existingThumbUrl;

  bool get _isEdit => widget.editProductId != null;

  @override
  void initState() {
    super.initState();
    if (!_isEdit) {
      _locationCtrl.text = 'Quận 1, TP.HCM';
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadCategories();
    if (_isEdit) await _loadForEdit();
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
          if (!_isEdit) {
            _categoryId = cats.isNotEmpty ? cats.first.categoryId : null;
          }
          _loadingCats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCats = false);
    }
  }

  Future<void> _loadForEdit() async {
    setState(() => _loadingEdit = true);
    try {
      final p = await ProductService.instance.getProductDetail(
        widget.editProductId!,
      );
      if (!mounted) return;
      setState(() {
        _titleCtrl.text = p.title;
        _descCtrl.text = p.description;
        _priceCtrl.text = p.price.toString();
        _locationCtrl.text = p.location;
        _condition = p.conditionPct.toDouble().clamp(65, 100);
        _categoryId = p.categoryId ??
            (_categories.isNotEmpty ? _categories.first.categoryId : null);
        _existingThumbUrl = p.thumbnailUrl ??
            (p.imageUrls.isNotEmpty ? p.imageUrls.first : null);
        _loadingEdit = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEdit = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không tải tin để sửa: $e')),
      );
      Navigator.pop(context);
    }
  }

  int get _remainingSlots => _maxImages - _images.length;

  Future<void> _addFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    final toAdd = files.take(_remainingSlots).toList();
    final previews = <Uint8List>[];
    for (final f in toAdd) {
      previews.add(await f.readAsBytes());
    }
    if (!mounted) return;
    setState(() {
      _images.addAll(toAdd);
      _previews.addAll(previews);
    });
    if (files.length > toAdd.length && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chỉ được tối đa $_maxImages ảnh')),
      );
    }
  }

  Future<void> _pickFromCamera() async {
    final file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null) return;
    await _addFiles([file]);
  }

  Future<void> _pickFromGallery() async {
    final files = await _picker.pickMultiImage(
      imageQuality: 85,
      maxWidth: 1600,
    );
    await _addFiles(files);
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _previews.removeAt(index);
    });
  }

  void _showImageSourceSheet() {
    if (_remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã đạt tối đa $_maxImages ảnh')),
      );
      return;
    }
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
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện (nhiều ảnh)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_isEdit && _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng thêm ít nhất 1 ảnh sản phẩm (bắt buộc)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final conditionErr = InputValidators.productCondition(_condition.round());
    if (conditionErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(conditionErr)),
      );
      return;
    }
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chọn danh mục sản phẩm')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final price = int.parse(
        _priceCtrl.text.replaceAll('.', '').replaceAll(',', ''),
      );
      if (_isEdit) {
        await ProductService.instance.updateProduct(
          widget.editProductId!,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: price,
          conditionPct: _condition.round(),
          location: _locationCtrl.text.trim(),
          categoryId: _categoryId!,
        );
      } else {
        await ProductService.instance.createProduct(
          images: _images,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          price: price,
          conditionPct: _condition.round(),
          location: _locationCtrl.text.trim(),
          categoryId: _categoryId!,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Đã cập nhật tin đăng!' : 'Đăng bán thành công!'),
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

  Widget _buildImagePicker() {
    if (_isEdit) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_existingThumbUrl != null && _existingThumbUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                ApiConfig.mediaUrl(_existingThumbUrl),
                width: 110,
                height: 110,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 110,
                  height: 110,
                  color: const Color(0xFFE5E7EB),
                  child: const Icon(Icons.image_outlined),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            'Bản này giữ ảnh cũ khi sửa tin (đổi ảnh: ẩn tin cũ và đăng lại).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      );
    }
    return SizedBox(
      height: 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length + (_remainingSlots > 0 ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index >= _images.length) {
            return _buildAddTile();
          }
          return _buildThumb(index);
        },
      ),
    );
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.primary),
            SizedBox(height: 6),
            Text(
              'Thêm ảnh',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb(int index) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _previews[index],
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
          if (index == 0)
            Positioned(
              left: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Ảnh bìa',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          Positioned(
            right: 2,
            top: 2,
            child: GestureDetector(
              onTap: () => _removeImage(index),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Sửa tin đăng' : 'Đăng bán sản phẩm'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: (_loadingCats || _loadingEdit)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ảnh sản phẩm *',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${_images.length}/$_maxImages',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Thêm nhiều ảnh (nhiều góc, chi tiết) để người mua thấy rõ. Ảnh đầu tiên là ảnh bìa.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildImagePicker(),
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
                      maxLength: InputValidators.maxProductDescription,
                      decoration: InputDecoration(
                        labelText: 'Mô tả',
                        hintText: 'Tình trạng, phụ kiện kèm theo...',
                        border: const OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                        counterText:
                            '${_descCtrl.text.length}/${InputValidators.maxProductDescription}',
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: InputValidators.productDescription,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Giá (VNĐ) *',
                        hintText: 'Tối thiểu 50.001đ',
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: AppColors.white,
                      ),
                      validator: InputValidators.productPrice,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Độ bền / tình trạng: ${_condition.round()}% (tối thiểu ${InputValidators.minProductCondition}%)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Slider(
                      value: _condition,
                      min: InputValidators.minProductCondition.toDouble(),
                      max: 100,
                      divisions: 7,
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
                          : Text(
                              _isEdit ? 'Lưu thay đổi' : 'Đăng bán ngay',
                              style: const TextStyle(
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
