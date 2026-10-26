# work_time

출퇴근·휴가를 달력과 날짜별 리스트에서 입력하고 초과·부족시간을 확인하는 Flutter 앱이다. Material Design 3와 MVVM을 사용하며 Web·Android·iOS를 대상으로 한다.

## 파일과 데이터
- CSV 불러오기: 시스템 파일 선택창에서 .csv 파일을 고르고 검증 후 모든 날짜 기록을 교체한다.
- CSV 저장 위치 선택: 파일 이름·위치를 선택해 모든 월 기록을 내보낸다. 같은 파일을 선택하면 시스템의 덮어쓰기 확인을 따른다.
- Web: 지원 브라우저는 저장 대화상자, 미지원 브라우저는 다운로드를 사용한다. 브라우저는 전체 파일 경로를 앱에 공개하지 않는다.
- 날짜 입력의 저장은 기기 보관이다. CSV 파일에 아직 반영하지 않은 기록은 저장 필요 상태로 표시한다.
- 앱 재실행 시 기기 스냅샷을 복원한다. 기기·브라우저 데이터 삭제에 대비하려면 CSV 파일로 저장한다.
- CSV 하나에 모든 연도·월을 저장한다. 파일에는 탭이 없으며 앱에서 날짜 열을 기준으로 월별 표시한다.

## 문서
- [개발 지침](AGENTS.md)
- [요구사항](docs/REQUIREMENTS.md)
- [MVVM 설계](docs/ARCHITECTURE.md)
- [CSV 저장 계약](docs/CSV_STORAGE.md)
- [시작 흐름](docs/APP_FLOW.md)
- [UI 기준](docs/UI_GUIDELINES.md)
- [Flutter 프롬프트](docs/FLUTTER_PROMPT.md)
- [개발 계획·검증 결과](docs/PLAN.md)
- [테스트 기준](docs/TESTING.md)
- [결정 기록](docs/DECISIONS.md)

## 실행
- `flutter pub get`
- `flutter run -d chrome --web-port 8085`
- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build apk --debug`

Windows 한글 사용자 임시 경로에서 테스트 엔진이 실패하면 `powershell -File tool/test.ps1`을 사용한다. Android 네이티브 의존성이 한글 캐시 경로에서 빌드되지 않으면 `powershell -File tool/build_android.ps1`을 사용한다. 두 스크립트는 해당 프로세스의 경로만 조정한다.

iOS 빌드는 macOS·Xcode가 필요하다. 지원 최소 OS와 실제 기기 검증은 개발 계획의 검증 결과를 참고한다.
