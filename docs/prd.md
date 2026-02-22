## 1. 프로젝트 개요

- **프로젝트 이름**: Vintly
- **한 줄 설명**: 빈티지 샵 및 제품 정보를 공유하고 소통하는 커뮤니티 모바일 앱
- **간단한 소개**:
  - 빈티지를 좋아하는 사람들만의 커뮤니티가 없어 기획하였다.
  - 빈티지 매장에 대한 위치, 사진 정보를 제공하고 좋아요 및 댓글을 쓸 수 있다.
  - 추후 게시글 기능을 추가하여 빈티지 제품(의류 등)에 대한 정보를 공유하고 게시글과 댓글로 소통하는 커뮤니티 앱으로 확장할 예정이다.

## 2. 타겟 유저 & 사용 시나리오

- **타겟 유저**:
  - 연령대: 20~40대
  - 지역: 대한민국(주로 경기, 서울)
  - 특징: 빈티지 패션/제품에 관심이 있는 누구나

- **주요 사용 시나리오 (User Stories)**:
  - "나는 **빈티지 옷을 좋아하는 직장인**으로서, **근처 좋은 빈티지 매장을 찾고 싶어서** 이 앱을 사용한다."
  - "나는 **빈티지 샵 사장**으로서, **내 빈티지 샵 관심도를 확인하기 위해** 사용한다."

- **핵심 User Story 리스트**:
  - [x] 유저는 회원가입 할 수 있다.
  - [x] 유저는 로그인 할 수 있다.
  - [x] 유저는 지도에서 빈티지 샵 목록을 보고 마커를 탭해 상세 정보를 볼 수 있다.
  - [x] 유저는 빈티지 샵에 좋아요를 누르거나 취소할 수 있다.
  - [x] 유저는 빈티지 샵에 댓글과 대댓글을 작성할 수 있다.

## 3. 핵심 기능 정의

- **구현 완료 (MVP)**:
  - **F1.** 회원가입
    - 설명: 회원가입 화면에서 이메일·비밀번호·닉네임으로 가입한다. (POST /api/v1/members/join)
    - 관련 화면: 회원가입 화면
  - **F2.** 로그인
    - 설명: 가입한 정보로 로그인한다. access/refresh 토큰 저장 후 홈(빈티지 목록)으로 이동.
    - 관련 화면: 로그인 화면
  - **F3.** 빈티지 샵 목록
    - 설명: GET /api/v1/vintages 로 목록을 받아 지도에 마커로 표시한다.
    - 관련 화면: 홈(빈티지 목록/지도 화면)
  - **F4.** 빈티지 샵 상세
    - 설명: 마커 탭 시 GET /api/v1/vintages/{id} 로 상세 조회. 이미지·이름·주소·좋아요 수·댓글(대댓글 트리) 표시.
    - 관련 화면: 홈 내 바텀시트
  - **F5.** 좋아요
    - 설명: POST/DELETE /api/v1/vintages/{id}/likes 로 좋아요 토글.
  - **F6.** 댓글·대댓글
    - 설명: POST /api/v1/vintages/{id}/comments. 일반 댓글은 parentCommentId=0, 대댓글은 parentCommentId=부모 commentId.

- **추가/차후 기능 (Nice to have)**:
  - **NF1.** 게시글(빈티지 제품 정보) CRUD
  - **NF2.** 알림, 채팅 등

## 3-1. 입력 검증 규칙 (MVP)

- **닉네임**: `^[가-힣A-Za-z0-9_-]{2,10}$`
  - 2~10자
  - 한글/영문/숫자/`_`/`-`만 허용
  - 공백 불가
- **이메일**
  - 최대 64자
  - 공백 불가
  - 기본 이메일 형식(`@`, `.` 포함) 체크
- **비밀번호**
  - 8~20자
  - 영문/숫자/특수문자 각각 최소 1개 포함
  - 공백 불가

## 4. 화면 설계 (UI / UX 개요)

- **전체 네비게이션 구조**:
  - Root(/) → 토큰 확인 → **Login** 또는 **Home(빈티지 목록)**
  - Login ↔ SignUp
  - Home: 지도 + 마커, 마커 탭 시 **상세 바텀시트** (이미지·이름·주소·좋아요·댓글/대댓글·입력)

- **주요 화면 목록**:
  - **S1. Root(스플래시) 화면**
    - 목적: 저장된 access 토큰 여부 확인 후 /home 또는 /login 으로 이동
    - 주요 요소: 로딩 인디케이터, "Vintly" 텍스트
  - **S2. 로그인 / 회원가입 화면**
    - 목적: 로그인·회원가입 후 토큰 저장, 홈으로 이동
    - 주요 요소: 이메일·비밀번호·닉네임(회원가입 시) 입력, 버튼
  - **S3. 홈(빈티지 목록) 화면**
    - 목적: 지도에 빈티지 샵 마커 표시, 마커 탭 시 상세 바텀시트
    - 주요 요소: flutter_map 지도, 마커, 로그아웃 등
  - **S4. 상세(바텀시트)**
    - 목적: 선택한 빈티지 샵의 이미지·이름·주소·좋아요 토글·댓글 목록(트리)·댓글/대댓글 입력

## 5. 데이터 모델 (간단 버전)

- **주요 엔티티**:
  - **VintageShop** (목록 한 건)
    - 필드: vintageId, name, state, district, detailAddr, lat, lon, thumbnailPath
  - **VintageShopDetail** (상세)
    - 필드: vintageId, name, state, district, detailAddr, imgList, likeCount, liked, comments, ...
  - **VintageComment**
    - 필드: commentId, memberId, nickname, content, createdAt, parentCommentId (0=일반, >0=대댓글)
  - **VintageImage**
    - 필드: vintageImgId, imgPath

- **백엔드 연동**:
  - REST API 서버 연동 완료. 환경별 baseUrl은 `lib/config/backend_*.dart` 에서 설정 (해당 파일은 .gitignore 대상).

## 6. 기술 스택 & 아키텍처

- **클라이언트(Flutter)**:
  - Flutter 3.x, Dart ^3.11.0
  - 주요 패키지:
    - 상태관리: setState (패키지 미사용)
    - 네트워크: `ApiClient` (dart `http` 기반), `getJsonWithAuth` / `postJsonWithAuth` / `deleteWithAuth`
    - 라우팅: `Navigator` named routes (`AppRoutes`)
    - 로컬 저장소: `flutter_secure_storage` (access/refresh 토큰)
    - 지도: `flutter_map`, `latlong2`

- **아키텍처**:
  - Feature 기반 폴더: `lib/features/auth`, `lib/features/vintage`, `lib/features/home`
  - 공통: `lib/shared/api`, `lib/shared/auth`, `lib/shared/ui`, `lib/config`, `lib/app`

- **API 인증 및 401 처리**:
  - 모든 인증 API에서 401 시 먼저 reissue 시도. access 토큰으로 호출 시 401이면 refresh로 POST /api/v1/auth/reissue 후 해당 API 한 번만 재시도.
  - 재시도 후에도 401이면 토큰 삭제 후 로그인 화면으로 유도.
  - 구현: `lib/shared/api/authenticated_api.dart` 의 `getJsonWithAuth`, `postJsonWithAuth`, `deleteWithAuth` 사용.

## 7. 비기능 요구사항

- **성능**: 첫 화면·목록 로딩 및 지도 스크롤 시 끊김 없이 동작 목표.
- **품질**: 다크 모드 미지원(추후 가능). 최소 지원 OS는 Flutter 기본 권장(Android/iOS).
- **언어/로케일**: 한국어 위주.

## 8. 우선순위 및 일정 (Optional)

- **1차 릴리즈(MVP)**: 회원가입·로그인·빈티지 목록·상세·좋아요·댓글/대댓글 구현 완료.
- **향후 로드맵**: 게시글(제품) CRUD, 알림, 채팅 등.

## 9. 기타 / 참고사항

- 메인 색상: 브라운·녹색 톤 (seedColor 0xFF4E342E, secondary 0xFF2E7D32).
