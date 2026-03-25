// =============================================================================
// 게시글 작성 — POST /api/v1/boards multipart (title, content, images≤10)
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/board_api_paths.dart';

class BoardCreateScreen extends StatefulWidget {
  const BoardCreateScreen({super.key});

  @override
  State<BoardCreateScreen> createState() => _BoardCreateScreenState();
}

class _BoardCreateScreenState extends State<BoardCreateScreen> {
  static const int _maxImages = 10;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _images = [];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;

    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(
      limit: remaining,
    );

    if (!mounted || picked.isEmpty) return;
    setState(() {
      for (final x in picked) {
        if (_images.length >= _maxImages) break;
        _images.add(x);
      }
    });
  }

  void _removeAt(int i) {
    setState(() => _images.removeAt(i));
  }

  String _filenameFor(XFile x, int index) {
    final n = x.name.trim();
    final raw = n.isNotEmpty ? n : 'image_$index.jpg';
    return raw.replaceAll(RegExp(r'["\\\r\n]'), '_');
  }

  String _contentTypeFor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 입력해 주세요.')),
      );
      return;
    }

    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final files = <({String filename, List<int> bytes, String contentType})>[];
      for (var i = 0; i < _images.length; i++) {
        final x = _images[i];
        final fn = _filenameFor(x, i);
        final bytes = await x.readAsBytes();
        files.add((filename: fn, bytes: bytes, contentType: _contentTypeFor(fn)));
      }

      final response = await postMultipartWithAuth(
        baseUrl,
        BoardApiPaths.createBoard,
        fields: {
          'title': title,
          'content': content,
        },
        fileFieldName: 'images',
        files: files,
      );

      if (!mounted) return;

      final code = response.code ?? response.statusCode;
      if (response.statusCode == 401 || code == 401 || response.statusCode == 403 || code == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      final ok = response.json['success'] == true &&
          (response.statusCode == 200 || response.statusCode == 201) &&
          (code == 200 || code == 201);
      if (ok) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.msg ?? '등록에 실패했습니다.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('글 작성'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: cs.outline.withValues(alpha: 0.2),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
                  )
                : const Text('등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '제목',
              hintText: '제목',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(
              labelText: '내용',
              hintText: '내용',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            minLines: 6,
            maxLines: 14,
            maxLength: 10000,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '이미지 (최대 $_maxImages장)',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed:
                    _images.length >= _maxImages || _submitting ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('사진'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_images.isEmpty)
            Text(
              '첨부 없이 등록할 수 있습니다.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_images[index].path),
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => ColoredBox(
                            color: cs.surfaceContainerHighest,
                            child: const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            fixedSize: const Size(28, 28),
                          ),
                          onPressed: _submitting ? null : () => _removeAt(index),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
