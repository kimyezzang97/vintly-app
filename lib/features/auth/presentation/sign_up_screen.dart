import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_config.dart';
import '../../../shared/api/api_client.dart';
import '../../../shared/ui/vintly_dialog.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SignUpScreenBody();
  }
}

class _SignUpScreenBody extends StatefulWidget {
  const _SignUpScreenBody();

  @override
  State<_SignUpScreenBody> createState() => _SignUpScreenBodyState();
}

class _SignUpScreenBodyState extends State<_SignUpScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  static final RegExp _nicknameRegex =
      RegExp(r'^[가-힣A-Za-z0-9_-]{2,10}$');
  // 8~20자, 영문/숫자/특수문자 각각 최소 1개 포함
  static final RegExp _passwordRegex =
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9\s])\S{8,20}$');
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final api = ApiClient(baseUrl: baseUrl);

      final payload = <String, dynamic>{
        'nickname': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      try {
        final response = await api.postJson('/api/v1/members/join', body: payload);

        if (!mounted) return;

        if (response.code == 200) {
          // 성공 시: 화면에 작성된 Text를 그대로 Alert로 보여주기
          await showVintlyDialog(
            context,
            type: VintlyDialogType.success,
            title: '회원가입 완료',
            message: '회원가입 완료 이메일 인증 후 로그인해 주세요.',
            barrierDismissible: false,
          );
          if (!mounted) return;
          Navigator.of(context).pop(); // back to login
          return;
        }

        // 실패 시: 백엔드 msg를 그대로 Alert로 보여주기
        await showVintlyDialog(
          context,
          type: VintlyDialogType.error,
          title: '회원가입 실패',
          message: response.msg ?? '회원가입에 실패했습니다.',
        );
      } catch (_) {
        if (!mounted) return;
        await showVintlyDialog(
          context,
          type: VintlyDialogType.error,
          title: '오류',
          message: '네트워크/서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'VINTLY 시작하기',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '기본 정보만 입력하면 바로 사용할 수 있어요.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      maxLength: 10,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                        hintText: '예) vintlylover',
                        prefixIcon: Icon(Icons.person_outline),
                        counterText: '',
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return '닉네임을 입력해 주세요.';
                        if (!_nicknameRegex.hasMatch(v)) {
                          return '닉네임은 2~10자(한글/영문/숫자/_/ -)만 가능합니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      maxLength: 64,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(64),
                      ],
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        hintText: 'example@email.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        counterText: '',
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return '이메일을 입력해 주세요.';
                        if (v.length > 64) return '이메일은 64자 이하로 입력해 주세요.';
                        if (!v.contains('@') || !v.contains('.')) {
                          return '이메일 형식이 올바르지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      maxLength: 20,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        helperText: '영문/숫자/특수문자 포함 8~20자',
                      ),
                      validator: (value) {
                        final v = (value ?? '');
                        if (v.isEmpty) return '비밀번호를 입력해 주세요.';
                        if (!_passwordRegex.hasMatch(v)) {
                          return '비밀번호는 영문/숫자/특수문자를 포함해 8~20자로 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordConfirmController,
                      obscureText: _obscurePasswordConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                      maxLength: 20,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        LengthLimitingTextInputFormatter(20),
                      ],
                      decoration: InputDecoration(
                        labelText: '비밀번호 확인',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePasswordConfirm =
                                !_obscurePasswordConfirm,
                          ),
                          icon: Icon(
                            _obscurePasswordConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        helperText: '비밀번호를 한 번 더 입력해 주세요.',
                      ),
                      validator: (value) {
                        final v = (value ?? '');
                        if (v.isEmpty) return '비밀번호 확인을 입력해 주세요.';
                        if (!_passwordRegex.hasMatch(_passwordController.text)) {
                          return '비밀번호 조건을 먼저 확인해 주세요.';
                        }
                        if (v != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('회원가입'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed:
                          _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('이미 계정이 있어요. 로그인'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '※ 현재는 UI/검증만 구현되어 있으며, 실제 회원가입 저장은 추후 백엔드 연동 시 추가됩니다.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

