# Vintly Android 출시 점검 체크리스트

점검일: 2026-09-01  
대상: Google Play 첫 Android 출시

## 결론

현재 상태는 **출시 보류**다. 앱의 주요 기능과 앱 내 회원탈퇴는 구현되어 있지만, 아래 차단 항목을 해결하기 전에는 production AAB를 제출하면 안 된다.

### P0 — 출시 차단

- [x] 고유한 최종 `applicationId`와 `namespace` 확정
  - 둘 다 `com.vintly.app`으로 변경했다.
  - Play Console에 처음 만든 패키지 이름은 나중에 바꿀 수 없으므로 회사/서비스 소유 도메인 기반 이름을 먼저 확정한다.
  - 패키지 변경 시 `MainActivity.kt` 패키지 경로, 네이버 지도 콘솔 등록 정보도 함께 변경한다.
- [x] release 업로드 키 서명 구성
  - `release`가 `android/key.properties`에 지정된 업로드 키를 사용하도록 연결했다.
  - 업로드 keystore는 `G:\내 드라이브\vintly\android-upload-key\vintly-upload-key.jks`에 보관한다.
  - `key.properties`는 저장소에 커밋하지 않고 Gradle release signing에 연결한다.
  - `flutter build appbundle -t lib/main_prd.dart --release` 빌드를 완료했다.
  - Play App Signing을 사용하고 업로드 키 백업·복구 담당자를 정한다.
- [x] 개인정보처리방침 공개 및 앱 내 링크 추가
  - 공개된 개인정보처리방침과 이용약관을 로그인/회원가입 및 마이 화면에서 열 수 있다.
  - 수집 항목, 목적, 보관·파기, 제3자/처리위탁, 이용자 권리, 문의처, 시행일을 실제 백엔드 처리와 일치시킨다.
  - 이용약관은 `docs/안드로이드-출시/TERMS.md`에 기록하고 노션 공개 URL을 앱에 연결했다.
  - 회원가입의 만 14세 이상 및 필수 약관 동의 UI는 구현했다.
- [x] 계정 삭제용 웹 경로 준비
  - 앱 내 `마이 > 회원탈퇴`와 `DELETE /api/v1/members/me`는 구현되어 있다.
  - 개인정보처리방침 공개 페이지에서 앱을 설치하지 않은 사용자도 이메일로 계정 삭제를 요청할 수 있다.
  - 백엔드는 탈퇴 시 계정 개인정보를 삭제하고 유지되는 게시글·댓글의 작성자를 익명 처리한다.
- [ ] production 환경과 AAB 재현 빌드 확정
  - `lib/config/backend_prd.dart`는 의도적으로 Git 제외되어 있어 CI/릴리스 담당자가 안전하게 주입할 방법이 필요하다.
  - `flutter build appbundle -t lib/main_prd.dart --release` 성공, AAB 설치 테스트, 네이버 지도 production 인증을 확인한다.
- [x] 2026-08-31 이후 제출 요건인 target API 36 확인
  - release 병합 manifest에서 `targetSdkVersion=36`, `minSdkVersion=24`를 확인했다.

## Release 업로드 키 생성 및 연결

키 저장 폴더는 `G:\내 드라이브\vintly\android-upload-key`로 통일한다. 아래 명령은 PowerShell에서 실행한다.

### 1. 폴더 준비

Google Drive에서 다음 폴더가 동기화되고 오프라인에서도 접근 가능한지 확인한다.

```text
G:\내 드라이브\vintly\android-upload-key
```

### 2. 업로드 키 생성

```powershell
keytool -genkeypair -v `
  -keystore "G:\내 드라이브\vintly\android-upload-key\vintly-upload-key.jks" `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

키 파일, alias `upload`, keystore 비밀번호와 key 비밀번호를 암호관리 도구에 별도로 보관한다. 동기화 드라이브만 유일한 백업으로 사용하지 않는다.

### 3. `android/key.properties` 작성

`android/key.properties`는 다음 형식을 사용한다. 비밀번호 자리에는 실제 값을 입력한다. 경로는 역슬래시 escaping 문제를 피하기 위해 `/`를 사용한다.

```properties
storePassword=실제_keystore_비밀번호
keyPassword=실제_key_비밀번호
keyAlias=upload
storeFile=G:/내 드라이브/vintly/android-upload-key/vintly-upload-key.jks
```

현재 `.gitignore`는 `key.properties`, `*.jks`, `*.keystore`를 제외한다. 생성 후 `git status --short`에 민감 파일이 나타나지 않는지 확인한다.

> 개발 환경 주의: `android/key.properties`와 업로드 키 파일은 보안상 Git에 포함되지 않는다. 따라서 저장소를 새 PC에 클론하거나 다른 개발 환경에서 실행할 때는 위 형식으로 `android/key.properties`를 직접 만들고, `storeFile`이 실제 업로드 키 경로를 가리키도록 설정해야 한다. 현재 Gradle 구성은 이 파일이 없으면 debug 실행을 포함한 Android Gradle 설정 단계에서 빌드가 중단된다. 비밀번호나 키 파일은 README, 문서, 소스 코드 또는 Git 저장소에 기록하지 않는다.

### 4. 인증서 지문 확인

```powershell
keytool -list -v `
  -keystore "G:\내 드라이브\vintly\android-upload-key\vintly-upload-key.jks" `
  -alias upload
```

첫 AAB 업로드 뒤 네이버 클라우드에는 로컬 업로드 키가 아니라 Play Console의 **앱 서명 키 인증서** SHA-1/SHA-256과 `com.vintly.app`을 최종 등록한다.

### P1 — 출시 전 반드시 정리

- [x] 앱 표시 이름을 `Vintly`로 변경
- [x] 아이콘 리소스 구성
  - 원본 워드마크 비율을 유지한 정사각형 launcher icon과 adaptive icon 배경/전경을 구성했다.
  - Android 런처별 원형·둥근 사각형 마스킹 결과는 실제 기기에서 최종 확인한다.
- [x] 스플래시 리소스 구성
  - Android 12+와 이전 버전의 흰 배경 중앙에 VINTLY 워드마크를 표시한다.
  - 앱의 Root 로딩 화면과 시스템 스플래시 전환은 실제 기기에서 최종 확인한다.
- [ ] 릴리스 로그 정책 확정
  - API logger는 일반 release에서 꺼지지만 `API_LOG=true`이면 요청/응답 body 전체를 출력할 수 있다. production 빌드 파이프라인에서 이 define을 금지한다.
  - 로그인·지도·빈티지 목록의 `debugPrint`는 release에서 보통 제거되지만 오류 객체/stack trace를 production 로그에 남기지 않는 원칙을 문서화한다.
- [ ] Play Console 앱 콘텐츠 작성
  - Data safety, 개인정보처리방침, 광고 포함 여부, 콘텐츠 등급, 타깃 연령, 앱 액세스를 완료한다.
  - 로그인이 필수이므로 심사팀용으로 항상 유효한 테스트 계정과 영문 접근 절차를 제공한다.
  - 현재 앱 코드에는 Firebase, 광고, 분석, 결제, 알림 SDK가 없다. 향후 추가하면 Data safety와 개인정보처리방침을 동시에 갱신한다.
- [ ] 병합 매니페스트와 SDK 데이터 흐름 검토
  - 직접 선언한 권한은 `INTERNET`뿐이다. release AAB/APK Analyzer에서 플러그인이 병합한 최종 권한을 확인한다.
  - 현재 주요 외부 패키지는 `flutter_secure_storage`, `flutter_naver_map`, `image_picker`, `url_launcher`다. 각 SDK와 백엔드가 전송·저장하는 데이터를 기준으로 Data safety를 작성한다.
- [ ] 16 KB 메모리 페이지 호환 확인
  - native library를 포함하는 Flutter/지도/플러그인 조합을 Play Console App Bundle Explorer 또는 16 KB emulator에서 검사한다.
- [ ] 스토어 등록 자료 준비
  - 앱명, 짧은/전체 설명, 휴대전화 스크린샷, 512×512 아이콘, 1024×500 그래픽, 지원 이메일/웹사이트, 카테고리, 국가/가격을 확정한다.
- [ ] 버전 전략 확정
  - 현재 `1.0.0+1`이다. 모든 업로드에서 `versionCode`가 증가하도록 릴리스 규칙과 changelog를 둔다.
- [ ] 백엔드 운영 준비
  - HTTPS 인증서, 장애/백업/복구, rate limit, 계정 삭제, 이미지 보관, 모니터링과 문의 대응을 검증한다.
  - 네트워크 timeout과 5xx/점검 상황에서 사용자에게 한국어 오류와 재시도 경로가 보이는지 확인한다.

## 기능별 판정

| 항목 | 코드 점검 결과 | 출시 전 확인 |
|---|---|---|
| 로그인/회원가입 | 구현됨, 토큰은 secure storage 사용 | 실서버 성공·실패·중복·토큰 만료·앱 재시작 |
| 계정 삭제 | 앱 내 UI/API 구현됨 | 서버 데이터 삭제 범위와 외부 웹 요청 URL |
| 결제 | 현재 제품 범위/코드에 없음 | 스토어 설명에서 결제를 암시하지 않기 |
| 알림 | 현재 미구현 제품 범위 | 권한 테스트 대상 아님. 출시 설명에 포함하지 않기 |
| 딥링크 | launcher 외 intent filter가 없어 미구현 | 요구 기능이 아니면 '미지원'으로 명시; 링크 마케팅 전에 구현 |
| 지도 | 네이버 지도 SDK 사용 | production client ID, 최종 package/signing 인증값, 지도 장애 |
| 사진 선택 | 시스템 picker 사용 | 취소, 권한/접근 제한, 큰 파일, HEIC/회전, 업로드 실패 |
| 외부 YouTube 링크 | 외부 앱 launch 구현 | YouTube 앱 없음, 잘못된 URL, 브라우저 실패 |
| Firebase/광고/분석 | 의존성에서 발견되지 않음 | Play Console 선언은 최종 AAB 기준으로 재확인 |

## 실제 Android 기기 테스트 매트릭스

자동 테스트로 대체할 수 없으므로 서명된 release 후보 AAB를 내부 테스트 트랙에 올려 진행한다.

### 권장 기기

- [ ] Android 7/API 24 또는 프로젝트 최소 버전에 가까운 저사양 기기
- [ ] Android 12/API 31 기기(시스템 스플래시 검수)
- [ ] Android 15/API 35 이상 기기
- [ ] 삼성 One UI 1대와 Pixel/AOSP 계열 1대
- [ ] 작은 화면/큰 글자 및 최신 고해상도 화면

### 스모크 시나리오

- [ ] 신규 설치 → 스플래시 → 회원가입 → 로그인 → 앱 재시작 자동 로그인
- [ ] 잘못된 이메일/비밀번호/닉네임 경계값과 서버 오류
- [ ] 지도 로딩, 이동, 마커, 상세, 좋아요, 댓글/대댓글 CRUD
- [ ] 커뮤니티 목록/상세/작성/수정/삭제, 다중 이미지와 업로드 실패
- [ ] YouTube 목록 페이지네이션, 외부 앱/브라우저 열기 실패
- [ ] 닉네임/비밀번호 변경, 로그아웃, 재로그인, 회원탈퇴
- [ ] access token 만료 → 1회 재발급 → 원 요청 재시도; refresh 만료 → 로그인 이동
- [ ] Wi-Fi/모바일 전환, 비행기 모드, 매우 느린 망, 요청 중 연결 끊김, 서버 401/404/500
- [ ] 사진 선택 취소 및 접근 제한. 현재 위치/카메라/알림 권한은 앱이 요청하지 않으므로 거부 테스트 대상이 아니다.
- [ ] 뒤로가기, 화면 회전/프로세스 재생성, 빠른 연속 탭, 백그라운드 복귀
- [ ] TalkBack, 글자 크기 200%, 키보드 입력, 대비와 터치 영역
- [ ] 30분 이상 탐색하며 메모리 증가, ANR, 크래시, 발열 확인

각 실행은 `기기 / OS / 앱 버전(versionCode) / 계정 / 단계 / 기대값 / 실제값 / 증거 / 담당자 / 날짜`로 기록한다.

## 자동 검증 명령

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build appbundle -t lib/main_prd.dart --release
```

AAB 생성 후에는 다음도 확인한다.

- Play Console 사전 출시 보고서의 크래시, ANR, 접근성, 보안 결과
- App Bundle Explorer의 target SDK, ABI, 다운로드 크기, 권한, native library/16 KB 호환
- 내부 테스트 설치본이 debug가 아닌 release 서버와 release 서명을 사용하는지
- `adb logcat`에 토큰, 비밀번호, 이메일, API response body 등 개인정보가 노출되지 않는지

## 이번 점검의 제한

- 연결된 실제 Android 기기와 Play Console 권한이 없어 기기 실행 및 사전 출시 보고서는 수행하지 못했다.
- Flutter 명령 묶음은 이 환경에서 출력 없이 장시간 대기해 중단했으므로 analyze/test/AAB 성공 여부는 아직 미확인이다.
- 백엔드 코드와 production 운영 설정이 이 저장소에 없어 회원탈퇴의 실제 데이터 파기 범위, 서버 로그/보관 기간, HTTPS/장애 대응은 확인하지 못했다.

## 공식 참고 자료

- [Google Play target API 요건](https://support.google.com/googleplay/android-developer/answer/11926878)
- [Google Play 계정 삭제 요건](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Data safety 작성 안내](https://support.google.com/googleplay/android-developer/answer/10787469)
- [앱 심사 준비 및 개인정보처리방침](https://support.google.com/googleplay/android-developer/answer/9859455)
- [로그인 앱의 심사용 접근 정보](https://support.google.com/googleplay/android-developer/answer/15748846)
- [Android 앱 서명 및 Play App Signing](https://developer.android.com/studio/publish/app-signing)
- [16 KB page size 지원](https://developer.android.com/guide/practices/page-sizes)
- [신규 개인 개발자 계정 테스트 요건](https://support.google.com/googleplay/android-developer/answer/14151465)
