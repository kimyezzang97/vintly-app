// =============================================================================
// 로그인 화면 (Login Screen)
// =============================================================================
//
// 이 화면에서 사용자가 이메일(username)과 비밀번호를 입력하고
// POST /login API를 호출합니다. 성공 시:
//   - access 토큰: 응답 헤더에서 읽어서 secure storage에 저장
//   - refresh 토큰: Set-Cookie에서 읽어서 secure storage에 저장
//   - 홈 화면으로 이동
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_config.dart';
import '../../../app/app_routes.dart';
import '../../../shared/api/api_client.dart';
import '../../../shared/auth/current_user.dart';
import '../../../shared/auth/token_storage.dart';
import '../../../shared/legal/legal_links.dart';
import '../data/login_tokens.dart';

/// 로그인 화면을 감싸는 StatelessWidget.
/// 실제 UI/상태는 _LoginScreenBody(StatefulWidget)에서 처리합니다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginScreenBody();
  }
}

class _LoginScreenBody extends StatefulWidget {
  const _LoginScreenBody();

  @override
  State<_LoginScreenBody> createState() => _LoginScreenBodyState();
}

class _LoginScreenBodyState extends State<_LoginScreenBody> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // 8~20자, 영문/숫자/특수문자 각각 최소 1개 포함
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9\s])\S{8,20}$',
  );
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  Future<void> _loadLastEmail() async {
    final email = await TokenStorage.getLastLoginEmail();
    if (email != null && email.isNotEmpty && mounted) {
      _emailController.text = email;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 로그인 버튼을 눌렀을 때 호출됩니다.
  /// 1) 폼 검증 2) API 호출 3) 토큰 파싱 및 저장 4) 홈으로 이동 또는 에러 메시지
  Future<void> _submit() async {
    // FormState에서 validate()를 호출하면 각 필드의 validator가 실행됩니다.
    // 하나라도 실패하면 false이고, 화면에 빨간 에러 문구가 표시됩니다.
    final form = _formKey.currentState;
    if (form == null) return;
    if (!form.validate()) return;

    // 버튼 비활성화 + 로딩 인디케이터 표시 (중복 제출 방지)
    setState(() => _isSubmitting = true);
    try {
      // 환경별 baseUrl (local/dev/prd)은 AppConfig에서 가져옵니다.
      final baseUrl = AppConfig.instance.backend.baseUrl;
      final api = ApiClient(baseUrl: baseUrl);

      // 백엔드 스펙: POST /login 의 body는 username, password
      final payload = <String, dynamic>{
        'username': _emailController.text.trim(),
        'password': _passwordController.text,
      };

      try {
        final response = await api.postJson(
          '/login',
          body: payload,
          redactKeys: const {'password'}, // 로그에 비밀번호는 *** 로만 찍힘
        );

        // 비동기 작업 후 화면이 이미 dispose 되었을 수 있으므로 mounted 체크
        if (!mounted) return;

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final tokens = LoginTokens.fromResponse(response);
          if (tokens == null) {
            await _clearAuthentication();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('서버에서 인증 정보를 받지 못했습니다. 다시 시도해 주세요.'),
              ),
            );
            return;
          }

          try {
            await TokenStorage.saveTokens(
              access: tokens.access,
              refresh: tokens.refresh,
            );
            await TokenStorage.saveLastLoginEmail(_emailController.text.trim());
          } catch (e, st) {
            debugPrint('[Login] TokenStorage.saveTokens failed: $e');
            debugPrint('[Login] stack: $st');
            await _clearAuthentication();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('인증 정보를 안전하게 저장하지 못했습니다. 다시 시도해 주세요.'),
              ),
            );
            return;
          }

          bool currentUserLoaded = false;
          try {
            currentUserLoaded = await fetchAndSetCurrentUser(
              AppConfig.instance.backend.baseUrl,
            );
          } catch (e, st) {
            debugPrint('[Login] current user verification failed: $e');
            debugPrint('[Login] stack: $st');
          }

          if (!currentUserLoaded) {
            await _clearAuthentication();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('사용자 정보를 확인하지 못했습니다. 다시 로그인해 주세요.')),
            );
            return;
          }

          if (!mounted) return;
          debugPrint('Login success. access=***, refresh=***');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('로그인 성공')));
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
          return;
        }

        final msg = response.msg ?? '로그인에 실패했습니다. 아이디/비밀번호를 확인해 주세요.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      } on FormatException catch (e) {
        // 서버가 HTML 에러 페이지 등 JSON이 아닌 응답을 주면 발생
        if (!mounted) return;
        debugPrint('[Login] FormatException: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('서버 응답 형식이 올바르지 않습니다. URL·서버 상태를 확인해 주세요.'),
          ),
        );
      } catch (e, st) {
        if (!mounted) return;
        // 디버그 시 콘솔에서 실제 원인 확인 가능 (예: 연결 거부, 타임아웃, JSON 파싱 실패)
        debugPrint('[Login] error: $e');
        debugPrint('[Login] stack: $st');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().length > 80
                  ? '오류가 발생했습니다. 콘솔 로그([Login] error)를 확인해 주세요.'
                  : '오류: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _clearAuthentication() async {
    CurrentUserHolder.clear();
    try {
      await TokenStorage.clearAll();
    } catch (e) {
      debugPrint('[Login] failed to clear tokens: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F1),
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
                    const SizedBox(height: 16),
                    Text(
                      'VINTLY',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '빈티지를 좋아하는 사람들을 위한 커뮤니티',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
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
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
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
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('로그인'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(
                              context,
                            ).pushNamed(AppRoutes.signUp),
                      child: const Text('회원가입'),
                    ),
                    const SizedBox(height: 16),
                    const LegalLinks(),
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
