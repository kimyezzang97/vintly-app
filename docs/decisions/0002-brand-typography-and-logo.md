# ADR 0002: 브랜드 폰트·로고·아이콘 자산 기준

- 상태: 채택
- 결정일: 2026-08-28
- 라이선스 확인일: 2026-08-28

## 배경

Vintly의 화면 개편 과정에서 `VINTLY` 워드마크, 본문 글꼴, 앱 아이콘과 화면 아이콘이 함께 사용되고 있다. 브랜드 표현을 일관되게 유지하고 출시 전에 자산의 상업적 사용 가능 여부를 확인할 수 있도록 현재 구현과 라이선스 판단을 기록한다.

## 현재 사용 현황

| 구분 | 현재 구현 | 저장소 포함 여부 | 무료·라이선스 판단 |
| --- | --- | --- | --- |
| UI 글꼴 | `ThemeData`와 개별 `TextStyle`에 `fontFamily`를 지정하지 않은 Flutter 기본 글꼴 | 별도 글꼴 파일 없음 | 별도의 글꼴 구매 비용 없음. 운영체제가 제공하는 시스템 글꼴과 fallback 글꼴을 사용한다. |
| 화면 워드마크 | `Text('VINTLY')` 또는 `Text('VINTLY 시작하기')` | 외부 로고 파일 없음 | 텍스트 자체에는 외부 이미지 자산 사용료가 없다. 다만 `VINTLY` 명칭의 상표 사용 가능 여부는 별도 확인이 필요하다. |
| 런처 아이콘 원본 | `assets/app_icon.png`의 베이지색 `VINTLY` 워드마크 | PNG 원본과 생성된 Android/iOS 아이콘 포함 | 저장소와 Git 이력에 제작 도구, 원본 폰트, 제작자 권리 또는 라이선스가 기록되어 있지 않아 **무료 사용 가능 여부를 확정할 수 없다.** 출시 전 출처 확인 또는 자체 제작 자산으로 교체한다. |
| 화면 아이콘 | Flutter의 `Icons.*`와 `uses-material-design: true` | Flutter가 Material Icons 글꼴을 앱에 포함 | Google이 Apache License 2.0으로 제공하므로 상업용 앱에서 비용 없이 사용할 수 있다. 재배포 시 해당 라이선스 조건은 유지한다. |
| Cupertino Icons | `cupertino_icons` 패키지가 의존성에 있으나 현재 `lib` 코드에서 사용하지 않음 | 의존성만 선언 | 현재 브랜드/UI 자산으로 간주하지 않는다. 향후 사용하면 사용 시점의 패키지 라이선스를 다시 기록한다. |

Flutter에서 커스텀 글꼴을 쓰려면 `pubspec.yaml`의 `fonts` 항목에 파일을 선언하고 `fontFamily`를 지정해야 한다. 현재 프로젝트에는 실제 `fonts` 선언과 `.ttf`·`.otf` 파일이 없으므로 특정 커스텀 폰트를 번들하지 않는다.

## 결정

### 글꼴

- 현재 단계에서는 커스텀 글꼴을 추가하지 않고 Flutter의 플랫폼 기본 글꼴을 유지한다.
- Android와 iOS의 실제 표시 글꼴은 운영체제 버전, 언어와 fallback 구성에 따라 달라질 수 있다. 따라서 현재 상태를 `Roboto 한 종 사용`처럼 표현하지 않는다.
- Apple 플랫폼의 SF Pro는 시스템 글꼴로 사용할 수 있지만, Apple에서 내려받은 폰트 파일은 별도 약관 대상이다. 해당 파일을 Android 또는 앱 자산으로 복사해 번들하지 않는다.
- 추후 동일한 한글 인상을 모든 플랫폼에서 보장해야 한다면 OFL 등 상업적 사용이 허용된 글꼴을 별도 ADR로 선정하고, 정확한 배포 파일과 라이선스 원문을 함께 보관한다.

### 워드마크와 로고

- 화면 헤더의 기본 워드마크는 대문자 `VINTLY`, 굵기 `w800`, 자간 `2.4`를 기준으로 한다.
- 로그인 화면은 현재 브랜드 브라운 `#4E342E`, 로그인 이후 주요 헤더는 캐러멜 `#A96F3D`를 사용한다. 두 색의 통일 여부는 전체 인증 화면과 메인 화면을 함께 검토할 때 결정한다.
- 현재 워드마크는 텍스트 스타일이며 독립된 공식 로고 파일로 보지 않는다.
- `assets/app_icon.png`는 출처가 확인될 때까지 임시 런처 아이콘으로 취급한다. 원본 폰트나 외부 로고를 이용해 만든 파일이라면 그 자산의 라이선스도 확인해야 한다.
- `VINTLY` 명칭과 로고의 상표 검색·등록 가능성은 이번 무료 라이선스 확인 범위에 포함되지 않았다. 출시 전 별도로 확인한다.

### 아이콘

- 화면 아이콘은 새로운 아이콘 세트를 도입하지 않고 Flutter Material Icons를 우선 사용한다.
- 외부 SVG, PNG 또는 유료 아이콘을 추가할 때는 출처와 라이선스가 확인되기 전까지 제품 코드에 포함하지 않는다.
- 네이버 지도 안의 NAVER 표기와 지도 저작권 표시는 Vintly 브랜드 자산이 아니라 지도 SDK의 필수 표기이므로 임의로 로고처럼 사용하거나 제거하지 않는다.

## 무료 사용 여부 결론

- **현재 UI 글꼴:** 별도 유료 폰트를 사용하지 않으므로 추가 비용 없음.
- **화면의 `VINTLY` 텍스트:** 외부 이미지 자산 비용 없음. 상표 사용 가능 여부는 미확인.
- **Material Icons:** Apache 2.0에 따라 비용 없이 상업적 사용 가능.
- **Roboto를 나중에 직접 번들하는 경우:** 현재 Google Fonts 배포본은 SIL Open Font License 1.1이며 상업용 앱에 포함할 수 있다. 정확히 내려받은 배포본의 `OFL.txt`를 함께 보관해야 한다.
- **현재 런처 아이콘 PNG:** 출처 정보가 없어 무료라고 확정할 수 없음. 출시 전 확인 또는 교체 필요.

여기서 `무료`는 별도의 구매·사용료가 없다는 뜻이며, 라이선스 고지·배포 조건이나 상표 확인까지 면제된다는 뜻은 아니다.

## 새 자산 추가 기준

폰트, 로고, 아이콘 또는 일러스트를 추가할 때 아래 항목을 함께 기록한다.

1. 자산명과 실제 파일 경로
2. 제작자 또는 배포처와 원본 URL
3. 라이선스 이름과 확인 날짜
4. 상업적 사용, 수정, 앱 번들·재배포 허용 여부
5. 필요한 저작자 표시와 라이선스 파일 보관 위치
6. 회사 또는 팀이 직접 제작했다면 제작자와 권리 귀속 근거

## 공식 확인 자료

- [Flutter 커스텀 폰트 적용 문서](https://docs.flutter.dev/cookbook/design/fonts)
- [Apple 플랫폼 글꼴 안내](https://developer.apple.com/fonts/)
- [Apple Typography 가이드](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Apple Design Resources 라이선스](https://developer.apple.com/support/downloads/terms/apple-design-resources/Apple-Design-Resources-License-20230621-English.pdf)
- [Google Roboto 저장소와 OFL 1.1 안내](https://github.com/googlefonts/roboto-3-classic)
- [SIL Open Font License FAQ](https://openfontlicense.org/ofl-faq/)
- [Google Material Icons 저장소와 Apache 2.0 안내](https://github.com/google/material-design-icons)

## 후속 작업

- [ ] `assets/app_icon.png`의 제작 방식, 원본 폰트와 권리 귀속을 확인한다.
- [ ] 출처를 확인할 수 없다면 정사각형 비율의 자체 제작 런처 아이콘으로 교체한다.
- [ ] 앱 출시 전에 오픈소스 라이선스 고지 화면 또는 고지 문서의 필요 범위를 점검한다.
- [ ] `VINTLY` 명칭과 최종 로고의 상표 사용 가능성을 확인한다.
