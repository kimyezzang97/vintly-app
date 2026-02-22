# Vintly

빈티지 샵 위치·정보를 공유하고, 좋아요와 댓글/대댓글로 소통하는 모바일 앱입니다.

## 기능

- **회원가입 / 로그인** – 이메일·비밀번호·닉네임 기반, access/refresh 토큰 저장
- **빈티지 샵 목록** – 지도에 마커로 표시, 목록 API 연동
- **빈티지 샵 상세** – 마커 탭 시 바텀시트로 이미지·이름·주소·좋아요·댓글 표시
- **좋아요** – 좋아요 토글 (POST/DELETE)
- **댓글·대댓글** – 댓글 작성 및 답글(대댓글) 작성

## 기술 스택

- **Flutter** 3.x, **Dart** ^3.11.0
- **지도**: flutter_map, latlong2
- **인증 저장**: flutter_secure_storage
- **네트워크**: REST API (dart `http` 기반 `ApiClient`), 401 시 자동 reissue 후 재시도

## 실행 방법

### 1. 저장소 클론 및 의존성 설치

```bash
git clone <repository-url>
cd vintly_app
flutter pub get
```

### 2. 백엔드 API 주소 설정

백엔드 baseUrl은 환경별로 다음 파일에서 설정합니다. (이 파일들은 `.gitignore`에 포함되어 있으므로, 프로젝트에 없으면 직접 생성해야 합니다.)

- `lib/config/backend_local.dart` – 로컬 개발
- `lib/config/backend_dev.dart` – 개발 서버
- `lib/config/backend_prd.dart` – 운영 서버

각 파일은 `backend_config.dart`의 `BackendConfig`를 사용해 `baseUrl`을 export합니다. 예시:

```dart
import 'backend_config.dart';

const backendConfig = BackendConfig(
  baseUrl: 'https://your-api-host.com',
);
```

### 3. 앱 실행

- 기본(개발 환경): `flutter run` (또는 `dart run lib/main_dev.dart` 등)
- 로컬 백엔드: `dart run lib/main_local.dart`
- 운영: `dart run lib/main_prd.dart`

`main.dart`는 현재 `backend_dev`를 사용하도록 되어 있을 수 있으므로, 필요 시 `lib/main.dart`에서 import하는 config를 변경하면 됩니다.

## 프로젝트 구조 (요약)

```
lib/
├── app/                 # 앱 진입점, 라우팅, 테마
├── config/              # 백엔드 설정 (backend_*.dart)
├── features/
│   ├── auth/            # 로그인, 회원가입
│   ├── home/            # 홈(임시)
│   └── vintage/         # 빈티지 목록·상세·좋아요·댓글
└── shared/
    ├── api/             # ApiClient, 인증 API 래퍼
    ├── auth/            # 토큰 저장, reissue
    └── ui/               # 공통 UI (다이얼로그 등)
```

## 문서

- [docs/prd.md](docs/prd.md) – 제품 요구사항·기능 정의·화면·데이터 모델·기술 스택

## 라이선스

Private.
