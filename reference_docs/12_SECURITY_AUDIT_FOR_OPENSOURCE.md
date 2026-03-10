# 🔐 12. 오픈소스를 위한 보안 감사 리포트 (Security Audit for Open Source)

본 레파지토리를 외부(GitHub Public 등)에 오픈소스로 공개하기 위해 진행한 **전체 디렉토리 보안 감사(Security Audit)** 결과 보고서입니다. 
외부에 노출되어서는 안 되는 하드코딩된 비밀번호, API 키, 엔드포인트, 내부망 주소, 개인정보 등이 존재하는지 검증했습니다.

---

## 🔎 1. 감사 항목 및 결과 요약 (Audit Summary)

| 검증 항목 (Audit Item) | 점검 결과 (Status) | 특이사항 (Notes) |
| :--- | :---: | :--- |
| **하드코딩된 Secret / Password / Token** | 🟢 **안전 (Safe)** | 테스트 클래스와 Default 메타데이터 레코드(`testSecretTest`) 외에 실제 비밀번호/토큰 유출 없음. |
| **실제 API Endpoint / URL 유출** | 🟢 **안전 (Safe)** | 통신은 Named Credential로 추상화되어 있으며, 오그 종속적인 URL 노출이 없음. |
| **Named Credential 및 인증 정보** | 🟢 **안전 (Safe)** | `namedCredentials` 폴더 자체가 레파지토리에 포함되지 않아 인증 정보(보안 키 등)가 물리적으로 격리됨. |
| **내부망 IP / 비인가 도메인** | 🟢 **안전 (Safe)** | 특이한 IP 주소나 내부망 도메인이 코드에 하드코딩된 내역 없음. |
| **사내 이메일 / 개발자 개인정보 노출** | 🔴 **조치 필요** | 일부 Apex 클래스 주석(Header)에 실제 개발자 및 외부 협력사(`@solomontech.net`) 이메일 노출됨. |

---

## 🛠️ 2. 상세 결과 및 조치 권고 사항 (Findings & Recommendations)

### 🟢 우수한 보안 설계 (Good Security Posture)
SOAR 프레임워크의 설계 구조 덕분에 외부 공개 시 발생할 수 있는 치명적인 보안 사고가 사전에 원천 차단된 상태입니다.
* **추상화된 통신 계층**: `InterfaceConfig__mdt` 메타데이터가 외부 통신 URL을 직접 갖지 않고, 오직 `Named Credential`의 이름 문자열(예: `IF_Teams_Base`, `IF_BusinessRegStatus`)만 가지고 있습니다.
* **물리적 분리**: 실제 Endpoint URL과 클라이언트 ID/Secret을 담고 있는 Salesforce의 `Named Credential` 메타데이터 파일들은 형상관리에 포함(Commit)되지 않아, 코드를 그대로 Public에 푸시해도 실제 서버가 해킹당할 위험이 0%입니다.
* **초기 설정값의 안전성**: `SecurityInboundConfig.Default.md` 파일에 들어있는 Secret 키 역시 `testSecretTest` 라는 더미(Dummy) 문자열로 구성되어 있어 훌륭합니다.

### 🔴 조치 필요 사항: 사내/협력사 개발자 이메일 노출
정규식(`@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}`)을 통해 전체 클래스를 스캔한 결과, 일부 Apex 클래스 최상단 `@author` 주석에 시스템 구축에 참여한 **솔로몬텍(@solomontech.net)** 소속 개발자들의 실제 이메일이 하드코딩되어 있습니다.

**[노출된 파일 목록]**
* `CommonUtilController.cls`: `iinokim@solomontech.net`
* `EmailConfigController.cls`: `payo03@solomontech.net`
* `CommonUtilCustomController.cls`: `payo03@solomontech.net`, `chaebeom.do@solomontech.net`
* `CaseViewHandlerController.cls`: `blacktick@solomontech.net`

*(참고: Test 클래스들에 존재하는 `test@example.com`, `test@salesforce.com` 등은 표준 더미 이메일이므로 수정하실 필요가 없습니다.)*

**💡 [조치 권고]**
오픈소스로 공개하기 전, 스팸 메일 수집 봇 등으로부터 개인정보를 보호하고 사내 정보 유출을 막기 위해 위 클래스 파일들에 포함된 이메일 주소를 **삭제**하거나, **`[Developer Name]`** 또는 **`@yourdomain.com`** 등 익명화된 플레이스홀더 패턴으로 수정(Scrubbing)하시는 것을 강력히 권장합니다.

---

## 🏁 3. 결론
이메일 주석 마스킹 작업 하나만 수행하신다면, 현재 레파지토리를 즉각적으로 Public 오픈소스로 전환하셔도 보안상(프라이빗 유출) **아무런 문제가 없는 매우 깔끔한 아키텍처**입니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
