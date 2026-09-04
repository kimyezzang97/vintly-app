import 'package:flutter/material.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../data/block_api.dart';
import '../data/blocked_member.dart';

class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  var _loading = true;
  String? _errorMessage;
  List<BlockedMember> _members = const [];
  final Set<int> _busyMemberIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _handleUnauthorized() async {
    await TokenStorage.clearAll();
    CurrentUserHolder.clear();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final response = await fetchBlockedMembers(
        AppConfig.instance.backend.baseUrl,
      );
      if (!mounted) return;
      final code = response.code ?? response.statusCode;
      if (response.statusCode == 401 || code == 401) {
        await _handleUnauthorized();
        return;
      }
      if (response.json['success'] != true) {
        setState(() {
          _loading = false;
          _errorMessage = response.msg ?? '차단 목록을 불러오지 못했습니다.';
        });
        return;
      }
      setState(() {
        _loading = false;
        _members = parseBlockedMembers(response);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = '차단 목록을 불러오는 중 오류가 발생했습니다.';
      });
    }
  }

  Future<void> _unblock(BlockedMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('차단 해제'),
        content: Text(
          '${member.nickname.isEmpty ? '이 사용자' : member.nickname}님의 차단을 해제할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('차단 해제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyMemberIds.add(member.memberId));
    try {
      final response = await unblockMember(
        AppConfig.instance.backend.baseUrl,
        member.memberId,
      );
      if (!mounted) return;
      final code = response.code ?? response.statusCode;
      if (response.statusCode == 401 || code == 401) {
        await _handleUnauthorized();
        return;
      }
      if (response.json['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.msg ?? '차단 해제에 실패했습니다.')),
        );
        return;
      }
      setState(() {
        _members = _members
            .where((item) => item.memberId != member.memberId)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('차단을 해제했습니다.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('차단 해제 중 오류가 발생했습니다.')));
      }
    } finally {
      if (mounted) setState(() => _busyMemberIds.remove(member.memberId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F1),
      appBar: AppBar(
        title: const Text('차단한 사용자'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('다시 시도')),
                  ],
                ),
              ),
            )
          : _members.isEmpty
          ? const Center(child: Text('차단한 사용자가 없습니다.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _members.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  final busy = _busyMemberIds.contains(member.memberId);
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE8E3DF)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          child: Icon(Icons.person_outline_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.nickname.isEmpty
                                    ? '사용자 #${member.memberId}'
                                    : member.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _formatBlockedDate(member.createdAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: busy ? null : () => _unblock(member),
                          child: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('차단 해제'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}

String _formatBlockedDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')} 차단';
}
