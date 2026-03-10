# ⚙️ 06. 외부 구성 및 메타데이터 설계 구조 (External Configurations & Metadata)

Security SOAR 프레임워크는 Apex 코드의 수정을 최소화하고, 관리자(Admin)가 런타임에 보안 정책과 연동 방식을 유연하게 제어할 수 있도록 **데이터 주도(Data-Driven) 아키텍처**로 설계되었습니다.

본 문서는 Apex 코드 외부에서 프레임워크의 뼈대를 지탱하는 **Custom Metadata Type(`__mdt`)** 과 **Named Credential** 등의 외부 구성 요소들의 역할과 구조를 자세히 명세합니다. 이 문서의 설정값들은 앞선 기획안(`01`, `02`, `03`, `04` 문서)에서 정의한 비즈니스 로직들이 정상적으로 동작하게 만드는 '설정 스위치' 역할을 합니다.

---

## 🏗️ 1. 핵심 Custom Metadata Types (`__mdt`)

SOAR 프레임워크는 총 4가지의 거대한 설정 축을 가지고 작동합니다.

### 🛡️ 1-1. `SecurityPolicy__mdt` (보안 정책 마스터)
가장 핵심이 되는 메타데이터로, 이벤트 발생 시 **[어떤 조건(Threshold)]** 일 때 **[어떤 조치(Action)]** 를 취할 것인지를 결정합니다. (참고: `02_ARCHITECTURE_DESIGN.md`의 정책 매핑부)

* **역할**: `SecurityAlertHandler`가 이벤트를 수신했을 때 가장 먼저 조회하여 룰을 가져옵니다.
* **주요 필드 (Fields)**:
    * `PolicyCode__c` (Text): 정책의 고유 식별자 (예: `MASS_DATA_EXPORT`, `NIGHT_LOGIN`)
    * `IsActive__c` (Checkbox): 정책 활성화 여부
    * `Severity__c` (Picklist): 기본 위협 수준 (Low, Medium, Critical)
    * `ActionTypes__c` (Text): 위협 감지 시 기본적으로 실행할 조치 목록 (콤마 분리, 예: `NOTIFY_SLACK, LOCK_USER`)
    * `ThresholdLow__c`, `ThresholdMedium__c`, `ThresholdCritical__c` (Number): 단위 시간당 발생 횟수 기반의 임계치 설정
    * `ActionLow__c`, `ActionMedium__c`, `ActionCritical__c` (Text): 임계치 도달 시 점진적으로 격상(Escalation)될 조치 목록

### 🔗 1-2. `SecurityIntegration__mdt` (액션과 인터페이스의 브릿지)
조치(Action) 파트에서 특정 조치가 실행될 때 **[어떤 방식(Sync/Async)]** 으로 **[어떤 외부 시스템(Interface)]** 에 연결될지를 결정합니다.

* **역할**: `SecurityInterfaceBridge`가 참조하여, 조치 타입에 맞는 알맞은 큐(Queueable, Batch 등)로 넘겨줄지 라우팅합니다.
* **주요 필드 (Fields)**:
    * `ActionType__c` (Text): 매핑될 액션 이름 (예: `NOTIFY_SLACK`)
    * `InterfaceId__c` (Text): 연결될 실제 인터페이스 설정의 식별자
    * `Mode__c` (Picklist): 실행 모드 (`REALTIME`, `QUEUEABLE`, `BATCH`)
    * `IsActive__c` (Checkbox): 연동 활성화 여부

### 🌐 1-3. `InterfaceConfig__mdt` (외부 시스템 통신 규격)
외부 시스템(Slack, Teams, SIEM 등)과 실제로 HTTP/REST 통신을 하기 위한 물리적/기술적 세부 설정을 담고 있습니다.

* **역할**: `InterfaceFactory` 또는 `InterfaceRealTime` 객체가 Callout을 수행할 때 엔드포인트와 인증 정보, 타임아웃 등을 세팅하는 데 사용됩니다.
* **주요 필드 (Fields)**:
    * `ImplementationClassName__c` (Text): 이 설정을 처리할 구체적 Apex 구현체 클래스명
    * `NamedCredential__c` (Text): **(가장 중요)** 외부 인증 처리를 위임할 Named Credential의 API Name
    * `ResourcePath__c` (Text): 엔드포인트 URL의 세부 경로 (Base URL은 Named Credential에 존재)
    * `Method__c` (Text): HTTP 메서드 (GET, POST 등)
    * `Timeout__c` (Number): 통신 타임아웃 제한 (밀리초 단위)
    * `BatchSize__c` (Number): 배치 모드일 경우 한 번에 처리할 청크(Chunk) 사이즈
    * `isActive__c` (Checkbox): 설정 자체의 활성화 여부

### 🚪 1-4. `SecurityInboundAction__mdt` (인바운드 웹훅 라우팅)
외부(예: 사내 메신저 승인 버튼 등)에서 Salesforce로 거꾸로 들어오는 Inbound Webhook 요청을 **[어떤 Apex 로직]** 으로 라우팅할지 결정합니다.

* **역할**: `SecurityActionInboundHandler`가 외부 유입 요청의 식별자를 보고 권한 이관(Privilege Escalation)을 씌울 목적지 클래스를 찾습니다.
* **주요 필드 (Fields)**:
    * `InboundActionType__c` (Text): 인바운드 요청에 명시된 식별 파라미터값
    * `ActionClassName__c` (Text): 해당 요청을 처리할 대상 콜백 Apex 클래스명
    * `RequiresToken__c` (Checkbox): JTI 토큰 기반의 무결성/만료 검증을 강제할지 여부

---

## 🔑 2. 인증 및 엔드포인트 보안 (Named Credentials)

SOAR 프레임워크가 외부(Slack, Teams, SPLUNK 등)로 알림을 보내거나 조치를 취할 때, **Apex 코드 내부에 하드코딩된 토큰이나 비밀번호는 단 1건도 존재하지 않습니다.** 모든 외부 인증은 Salesforce 표준 기능인 **Named Credentials**에 위임됩니다.

### 2-1. 왜 Named Credentials를 사용하는가?
* **Callout Limit 회피**: Named Credential을 사용하면 인증 절차를 플랫폼이 대신 해주어 코드가 간결해집니다.
* **보안성 확보**: 토큰 갱신(Refresh Token)이나 암호화 저장을 Salesforce 플랫폼(Secure String)이 책임집니다.
* **환경별 유연성**: 샌드박스와 운영(Production) 환경에서 코드를 바꿀 필요 없이 Named Credential 설정만 다르게 세팅하면 됩니다.

### 2-2. 운영 체계 연동 예시
`InterfaceConfig__mdt`의 `NamedCredential__c` 필드에 다음과 같은 레코드들이 매핑되어 돌아갑니다.
1. `NC_Slack_Security_Alerts`: OAuth 2.0 또는 Webhook URL 기반의 Slack 연동.
2. `NC_Teams_Webhook`: Microsoft Teams의 보안 채널 연동.
3. `NC_Splunk_HEC`: SIEM 장비로의 Http Event Collector 인증 연동.

---

## 🔄 3. 아키텍처 문맥에서의 메타데이터 라이프사이클 (The Big Picture)

우리가 작성한 설계 문서(`01` ~ `04`)의 흐름에 메타데이터가 파고드는 위치는 다음과 같습니다.

1. **[감지]** 트랜잭션 보안 정책(TxnSecurity) 트리거 발생
2. **[평가]** `SecurityGuard`가 `SecurityPolicy__mdt`를 로드하여 임계치 및 수행할 조치(ActionType) 결정 (`02` 아키텍처 문서 참고)
3. **[게시]** 조치 정보가 포함된 플랫폼 이벤트(`SecurityAlert__e`) 발행
4. **[구독 및 분배]** `SecurityInterfaceBridge`가 `SecurityIntegration__mdt`를 읽어 해당 액션의 모드(Sync/Async) 파악
5. **[실행 준비]** 팩토리에서 액션(`ISecurityAction`)을 생성하고, `InterfaceConfig__mdt`를 로드 (`03` 세부 설계 문서 참고)
6. **[Callout]** `InterfaceConfig__mdt`에 적힌 Named Credential을 활용하여 외부망으로 격리된 채널(Slack)에 차단 사실 안전하게 전송

---

## 📌 요약 및 향후 리팩토링 연계 (`05` 문서 관련)

현재 이 강력한 메타데이터 구조는 아주 잘 설계되어 있으나, 각 클래스에서 산발적으로 SOQL 쿼리를 날려 메타데이터를 끌어오는 파편화(Fragmentation) 현상이 있습니다.

이 문제를 해결하기 위해 `05_REFACTORING_OPPORTUNITIES.md`의 **Tier 2 - 5번(메타데이터 중앙 제어 / Singleton Pattern)** 조치가 예정되어 있으며, 향후 중앙 싱글톤 레지스트리(`SecurityMetadataRegistry`)가 도입되면 메타데이터 인프라의 성능이 궁극의 단계로 최적화될 것입니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
