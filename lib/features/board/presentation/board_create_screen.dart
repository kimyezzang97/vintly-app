// =============================================================================
// 게시글 작성 — POST /api/v1/boards multipart (title, content, images≤10)
// 게시글 수정 — PATCH /api/v1/boards/{id} multipart
//   title, content, raminImgIdList(JSON 배열), imgList(신규 파일)
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/authenticated_api.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/board_api.dart';
import '../data/board_api_paths.dart';
import '../data/board_detail.dart';

String _boardCreateResolveImageUrl(String baseUrl, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    return trimmed;
  }
  final base = baseUrl.replaceAll(RegExp(r'/$'), '');
  return trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
}

Map<String, String>? _boardCreateImageHeaders(
  String baseUrl,
  String imageUrl,
  String? access,
) {
  if (access == null || access.isEmpty) return null;
  final imageUri = Uri.tryParse(imageUrl);
  final baseUri = Uri.tryParse(baseUrl);
  if (imageUri == null || baseUri == null || !imageUri.hasScheme) return null;
  if (imageUri.host.isEmpty) return null;
  if (imageUri.host != baseUri.host || imageUri.port != baseUri.port) {
    return null;
  }
  return {'access': access};
}

class BoardCreateScreen extends StatefulWidget {
  const BoardCreateScreen({
    super.key,
    this.editBoardId,
    this.initialTitle,
    this.initialContent,
    this.existingImages = const [],
  });

  /// null이면 신규 작성, 있으면 [PATCH] 수정.
  final int? editBoardId;
  final String? initialTitle;
  final String? initialContent;
  /// 수정 시 유지할 기존 이미지 (삭제한 항목은 [raminImgIdList]에서 빠짐).
  final List<BoardDetailImageRef> existingImages;

  @override
  State<BoardCreateScreen> createState() => _BoardCreateScreenState();
}

class _BoardCreateScreenState extends State<BoardCreateScreen> {
  static const int _maxImages = 10;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _images = [];
  List<BoardDetailImageRef> _retainedExisting = [];
  bool _submitting = false;

  bool get _isEdit => widget.editBoardId != null;

  int get _totalImageCount => _retainedExisting.length + _images.length;

  @override
  void initState() {
    super.initState();
    final t = widget.initialTitle;
    if (t != null && t.isNotEmpty) _titleController.text = t;
    final c = widget.initialContent;
    if (c != null && c.isNotEmpty) _contentController.text = c;
    if (_isEdit) {
      _retainedExisting = List<BoardDetailImageRef>.from(widget.existingImages);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImageCount;
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

  void _removeRetainedExistingAt(int i) {
    setState(() => _retainedExisting.removeAt(i));
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

    if (_isEdit) {
      for (final r in _retainedExisting) {
        if (r.imgId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '일부 기존 이미지에 ID가 없어 서버에 유지 요청을 할 수 없습니다. '
                '해당 사진을 목록에서 제거한 뒤 다시 추가해 주세요.',
              ),
            ),
          );
          return;
        }
      }
    }

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

      final response = _isEdit
          ? await boardPatchUpdate(
              baseUrl,
              widget.editBoardId!,
              title: title,
              content: content,
              raminImgIdListJson: jsonEncode(
                _retainedExisting.map((e) => e.imgId!).toList(),
              ),
              newImageFiles: files,
            )
          : await postMultipartWithAuth(
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

      final apiCode = response.code;
      if (response.statusCode == 401 ||
          apiCode == 401 ||
          response.statusCode == 403 ||
          apiCode == 403) {
        await TokenStorage.clearAll();
        CurrentUserHolder.clear();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.login,
          (route) => false,
        );
        return;
      }

      final businessOk =
          response.json.isEmpty || response.json['success'] == true;
      final statusOk = response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204;
      final codeOk = apiCode == null ||
          apiCode == 0 ||
          apiCode == 200 ||
          apiCode == 201 ||
          apiCode == 204;
      if (businessOk && statusOk && codeOk) {
        Navigator.of(context).pop(true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.msg ??
                (_isEdit ? '수정에 실패했습니다.' : '등록에 실패했습니다.'),
          ),
        ),
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
        title: Text(_isEdit ? '글 수정' : '글 작성'),
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
                : Text(_isEdit ? '저장' : '등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isEdit && _retainedExisting.isNotEmpty) ...[
            Text(
              '유지할 기존 이미지 (×로 제거)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: FutureBuilder<String?>(
                future: TokenStorage.getAccessToken(),
                builder: (context, snap) {
                  final access = snap.data;
                  final baseUrl = AppConfig.instance.backend.baseUrl;
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _retainedExisting.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final ref = _retainedExisting[index];
                      final resolved = _boardCreateResolveImageUrl(
                        baseUrl,
                        ref.path,
                      );
                      if (resolved.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      final headers = _boardCreateImageHeaders(
                        baseUrl,
                        resolved,
                        access,
                      );
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              resolved,
                              width: 96,
                              height: 96,
                              fit: BoxFit.cover,
                              headers: headers,
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
                              onPressed: _submitting
                                  ? null
                                  : () => _removeRetainedExistingAt(index),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
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
                onPressed: _totalImageCount >= _maxImages || _submitting
                    ? null
                    : _pickImages,
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
