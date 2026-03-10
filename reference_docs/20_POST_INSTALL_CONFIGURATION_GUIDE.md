# 🛠️ 20. 패키지 설치 후 필수 설정 가이드 (Post-Install Configuration)

본 프레임워크는 배포 및 유지보수의 유연성을 위해 순수 로직(Apex, Custom Object 등)만 패키지(`Base-Interface`, `Security-SOAR`)에 포함합니다. 

통신 도메인, 인증 정보, 퍼블릭 사이트 주소 등 **환경(Sandbox/Production)마다 값이 달라지거나 보안상 패키지에 말아서 배포하면 안 되는(Anti-Pattern) 설정들**은 패키지에서 의도적으로 제외되었습니다.

따라서 패키지를 대상 Org에 설치한 후, 관리자는 반드시 아래의 **Post-Install 설정**을 수동으로 진행해야 정상적인 Inbound/Outbound 동작을 수행할 수 있습니다.

---

## 🔒 1. Outbound 연동 환경 설정 (외부로 알림/API 전송)

SOAR에서 Slack, Teams, SIEM 등으로 외부 HTTP Callout을 보내기 위해 필요한 네트워크 타겟 설정입니다. (이 설정이 누락되면 `System.CalloutException`이 발생합니다.)

### 1️⃣ Remote Site Settings 등록
Salesforce가 외부 도메인을 신뢰하고 통신을 허가하도록 등록합니다.

- **메뉴 경로**: Setup > Security > Remote Site Settings
- **설정 항목**:
  1. **Slack Webhook**: `https://hooks.slack.com`
  2. **MS Teams Webhook**: `https://(company).webhook.office.com`
  3. **내부 SIEM / DataDog 등**: 각 회사의 로깅 서버 엔드포인트 도메인
- **주의사항**: `Disable Protocol Security`는 체크 해제 상태(기본값)를 유지합니다.

### 2️⃣ Named Credentials (또는 HTTP Callout Config) 설정
하드코딩된 API Key 방식 대신, Named Credential을 통해 외부 인증 헤더를 안전하게 관리하는 것을 권장합니다.

- **메뉴 경로**: Setup > Security > Named Credentials
- **설정 방법**: 
  - (Slack 예시) `NamedCredential` Name: `Slack_Notifier`, URL: `https://hooks.slack.com` 지정
  - Authentication Type을 지정하여 `Authorization` 헤더를 안전하게 보관합니다.
- **적용**: 이후 SOAR의 `HttpCalloutConfig__mdt` 메타데이터에서 Endpoint를 하드코딩된 URL 대신 `callout:Slack_Notifier/...` 와 같은 Named Credential 참조 값으로 설정합니다.

---

## 📡 2. Inbound 웹훅 환경 설정 (외부에서 액션 승인/거절)

Slack이나 MS Teams 방에서 "사용자 격리 승인" 버튼을 눌렀을 때, 그 결과가 Salesforce로 콜백(Callout) 되어 들어오려면 외부 접속용 Public URL이 열려있어야 합니다.

### 1️⃣ Salesforce Site (Public Community/Site) 셋업
인증(OAuth) 과정 없이 외부 웹훅 페이로드를 직접 수신할 공개 엔드포인트를 엽니다.

- **메뉴 경로**: Setup > User Interface > Sites and Domains > Sites
- **설정 항목**:
  1. 새 Site 생성 (예: `Security_SOAR_Webhook`)
  2. **Active** 체크박스 활성화
  3. Site의 Default Web Address (도메인) 복사
     - *예) `https://my-company.my.salesforce-sites.com`*

### 2️⃣ Site Guest User 권한 부여 (Public Access Settings)
방금 만든 Site로 들어오는 익명 사용자(Slack 서버 등)가 Apex REST API를 호출할 수 있도록 권한을 엽니다.

- **설정 방법**:
  1. 생성한 Site 설정 화면에서 **[Public Access Settings]** 버튼 클릭
  2. 이는 Profile 설정 화면과 동일합니다.
  3. **Apex Class Access**: `InboundRestHandler` 와 `IF_SecurityActionController` (혹은 구현한 REST Resource)에 접근 권한(Enable)을 부여합니다.
  4. (선택) **Custom Object Access**: 웹훅이 로그 스탬프를 찍어야 하므로 `HttpCalloutLog__c` 객체의 Create(C) 권한을 허용할 수 있습니다.

### 3️⃣ Inbound 보안 설정 (메타데이터 업데이트)
마지막으로 뚫어놓은 Site Public URL을 SOAR 설정에 기입하고, 서명(Signature) 기반 신뢰를 구성합니다.

- **메뉴 경로**: Setup > Custom Code > Custom Metadata Types > `SecurityGlobalConfig__mdt`
- **설정 값 검증**:
  - `BaseUrl__c`: 방금 만든 Site URL 기입 (`https://my-company.my.salesforce-sites.com`)
  - `HashSecretString__c`: Slack 등에서 콜백을 보낼 때 위변조를 검증키 위해 사용하는 암호화 대칭키(무작위 난수)를 갱신합니다. (외부 유출 금지)

---

## 🔑 3. 자동화 수행 권한 할당 (Permission Set Assignment)

SOAR 프레임워크가 악성 유저의 세션을 끊거나 다단계 인증(MFA)을 강제하는 자동화 액션(`SecurityKillSessionAction` 등)을 수행하려면, 시스템 컨텍스트(`SystemReq` Event) 또는 해당 로직을 트리거하는 유저에게 필요한 **관리자 수준의 시스템 권한**이 부여되어 있어야 합니다.

### 1️⃣ 패키징 권고 사항 (Best Practice)
- **패키지에 포함**: 앱 구동에 필수적인 커스텀 객체(`HttpCalloutLog__c` 등)와 메타데이터에 대한 CRUD 권한을 묶어둔 **가칭 `SOAR_Core_Permissions` Permission Set은 패키지에 함께 묶어서 배포**해야 합니다. (관리자가 일일이 필드 레벨 보안을 잡아줄 수 없기 때문입니다.)
- **패키지에서 제외 (할당 보류)**: 권한 집합 자체는 배포하지만, 그 권한을 특정 사용자나 통합 계정(Integration User)에게 **할당(Assign)** 하는 행위 자체는 패키지 설치 시점에 자동화할 수 없으므로 Post-Install 작업으로 남겨둡니다.

### 2️⃣ Post-Install 권한 할당 작업
- **메뉴 경로**: Setup > Users > Permission Sets
- **설정 항목**:
  1. 배포된 `SOAR_Core_Permissions` (가칭) 퍼미션 셋을 엽니다.
  2. **[Manage Assignments]** 버튼을 클릭합니다.
  3. 이 SOAR 솔루션의 관리 책임자, 그리고 백그라운드에서 외부 연동을 수행할 통합 전용 계정(Integration User)에게 이 퍼미션 셋을 할당합니다.
  4. (중요) 만약 플랫폼 이벤트(`SecurityActionRequest__e`)의 트리거를 비동기 대리 수행하는 구동 계정이 기본 시스템 계정(Automated Process)이라면, 해당 내부 계정에도 SOAR 객체에 대한 권한이 정상 부여되었는지 검증해야 에러 없이 조치 액션이 수행됩니다.

---

> 🎉 위 3가지 파트(Outbound 원격지 인증 + Inbound 웹훅 공개 포트 + Permission Set 할당) 설정을 모두 완료했다면 패키지 설치 후속 작업이 끝났습니다. 이제 메타데이터 모듈만 설정하면 모든 기능이 동작합니다!
