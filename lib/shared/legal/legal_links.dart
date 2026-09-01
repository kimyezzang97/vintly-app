import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const termsOfServiceUrl =
    'https://hip-payment-318.notion.site/Vintly-3cef6827431f805abc2fcd5c65beb26d?pvs=73';
const privacyPolicyUrl =
    'https://hip-payment-318.notion.site/3cef6827431f80eda958ea5d30b1a8ec';

Future<void> openLegalUrl(BuildContext context, String url) async {
  try {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
  } catch (_) {
    if (!context.mounted) return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('페이지를 열 수 없습니다. 잠시 후 다시 시도해 주세요.')),
  );
}

class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.alignment = WrapAlignment.center});

  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        TextButton(
          onPressed: () => openLegalUrl(context, termsOfServiceUrl),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('이용약관'),
        ),
        Text('·', style: Theme.of(context).textTheme.bodySmall),
        TextButton(
          onPressed: () => openLegalUrl(context, privacyPolicyUrl),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('개인정보처리방침'),
        ),
      ],
    );
  }
}
