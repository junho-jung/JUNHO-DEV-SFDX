# 🗂️ 21. SOAR 프레임워크 클래스 인벤토리 및 패키지 맵 (Class Inventory & Package Map)

본 문서는 Security SOAR 프레임워크를 구성하는 **모든 Apex 클래스와 트리거를 모듈(Layer) 단위로 분류하고, 실제 트랜잭션의 실행 흐름(Execution Flow) 순으로 정렬**한 종합 인벤토리입니다. 

향후 코드를 분석하거나 패키징(Packaging)을 수행할 때, 각 클래스가 어떤 역할을 담당하고 패키지 아카이브에 포함되어야 하는지(Include/Exclude)를 명확히 판별할 수 있습니다.

---

## 🌊 전체 실행 흐름 요약 (Execution Flow Summary)
이벤트 감지 ➡️ 조건 분석(Facade) ➡️ 페이로드 추출 ➡️ 이벤트 발행 ➡️ 정책 매핑/스로틀링 ➡️ 팩토리 동적 생성 ➡️ 액션 실행 ➡️ (외부) 웹훅/인바운드 콜백

---

## 1. 🛡️ 이벤트 감지 계층 (Event Interception Layer)
사용자의 행위가 Salesforce Transaction Security 정책에 의해 트리거될 때 가장 먼저 호출되는 진입점입니다.
> **패키징 전략**: 모두 SOAR Core 패키지에 **포함(Include)** 됩니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityBaseInterceptor` | 모든 인터셉터의 부모 클래스로, 공통 예외 처리 체계를 담당 | ✅ |
| `EM_SecurityBlockInterceptor` | 사용자의 심각한 위협(예: 데이터 대량 유출)을 즉시 차단(Block)하는 인터셉터 | ✅ |
| `EM_SecurityMFAInterceptor` | 고위험 작업 시 추가 인증(MFA)을 요구하는 인터셉터 | ✅ |
| `EM_SecurityMonitorInterceptor` | 행동을 차단하지는 않고 알림/관제용으로 감시(Monitor)만 하는 인터셉터 | ✅ |

---

## 2. 🏛️ 퍼사드 및 공통 유틸리티 계층 (Facade & Utility Layer)
인터셉터들이 내부의 복잡한 로직을 직접 부르지 않도록 앞단에 배치한 단일 진입점(Facade) 및 캐싱 유틸입니다.
> **패키징 전략**: 모두 SOAR Core 패키지에 **포함(Include)** 됩니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityGuard` | **[Facade]** 각 이벤트(Api, Report 등)의 위험도를 분석하는 단일 진입점 역할 | ✅ |
| `SecurityMetadataRegistry` | **[Singleton]** `SecurityPolicy__mdt` 등 메타데이터를 1회만 조회/캐싱하여 성능 최적화 | ✅ |
| `SecurityKillSwitch` | 장애 발생 시 커스텀 메타데이터 스위치로 전체 보안 모듈을 Emergency 중단하는 유틸 | ✅ |
| `SecurityPrivilegeEscalator` | System 모드(Without Sharing)로 강제 실행해야 하는 특정 DB 조작 헬퍼 | ✅ |
| `SecurityValidator` | 범용 보안 검증 유틸 (추후 Specification 패턴 적용 대상) | ✅ |
| `SecurityFilterChain` | 검증기들을 묶어 체인으로 관리하는 기능 (추후 Chain of Responsibility 확장용) | ✅ |
| `SecurityThrottleFilter` | 알람 중복 폭주를 막기 위한 개별 스로틀링 룰 검증 필터 | ✅ |
| `SecurityTypes` | 프레임워크 전역에서 공통으로 쓰는 Type(Struct), Enum 및 상수 정의 클래스 | ✅ |

---

## 3. 🧩 이벤트 추출 모델 계층 (Extractor Strategy Layer)
트랜잭션 시점(DML 불가)을 벗어나 비동기 버스로 넘기기 직전, DML이 가능한 JSON 형태로 데이터를 정제합니다.
> **패키징 전략**: 모두 SOAR Core 패키지에 **포함(Include)** 됩니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `IEventExtractor` | SObject 추출 로직의 표준을 정의하는 인터페이스 (Strategy) | ✅ |
| `DefaultEventExtractor` | 특별한 매핑이 없을 경우 사용되는 기본 JSON 직렬화 추출기 | ✅ |
| `ApiEventExtractor` | `ApiEvent` (REST, SOAP API 호출) 전용 페이로드/조건 추출기 | ✅ |
| `ReportEventExtractor`| `ReportEvent` (리포트/대시보드 Export) 전용 페이로드/조건 추출기 | ✅ |
| `LoginEventExtractor` | `LoginEvent` (접속/세션) 전용 페이로드/조건 추출기 | ✅ |

---

## 4. 🚀 오케스트레이션 및 라우팅 계층 (Orchestration Layer)
추출된 데이터로 플랫폼 이벤트를 발행하고, 이를 다시 구독하여 "누구에게 어떤 벌을 줄 것인가(Policy)" 결정합니다.
> **패키징 전략**: 모두 SOAR Core 패키지에 **포함(Include)** 됩니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityAlertPublisher` | 정제된 JSON 데이터를 바탕으로 `SecurityAlert__e` 이벤트를 비동기 버스에 Fire | ✅ |
| `SecurityAlert_tr` | `SecurityAlert__e` 이벤트의 Trigger 파일 | ✅ |
| `SecurityAlertHandler` | 큐에서 이벤트를 꺼내어 오케스트레이션 및 팩토리 생산을 제어하는 핵심 핸들러 | ✅ |
| `SecurityPolicyResolver` | 런타임에 주어진 위협 카운트(Threshold)를 분석하여 적합한 대응 Action 반환 | ✅ |
| `SecurityActionThrottle` | 연속 발생 시 "1시간에 1번만 알림" 등 서킷 브레이커 판단 수행 | ✅ |
| `SecurityAlertFallbackJob` | 플랫폼 이벤트 유실/장애 시 수동으로 배치 재처리(Fallback)를 돌려주는 Job | ✅ |

---

## 5. ⚙️ 동적 팩토리 및 실행 엔진 계층 (Execution Engine Layer)
정책에서 도달한 액션명(`NOTIFY_TEAMS` 등)을 실제 메모리 상의 Apex 객체로 조립하고(Type.forName), Queueable 전환 여부 등을 판단합니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `ISecurityAction` | 모든 보안 대응 액션이 반드시 구현해야 하는 단일 `execute()` 인터페이스 | ✅ |
| `SecurityActionFactory` | 리플렉션(Reflection)을 통해 문자열 기반으로 액션 인스턴스를 동적 로딩(OCP 준수) | ✅ |
| `SecurityActionExecutor`| 액션들을 받아 동기(Sync) 또는 비동기(Queueable)로 배분하고 수행 로그 이력을 남김 | ✅ |

---

## 6. ⚔️ 내부 환경 통제 액션 (Internal Action Layer)
실제 Salesforce 환경 내부의 유저, 세션, 권한을 제재하는 구체적인 로컬 조치 클래스들입니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityBaseAction` | 페이로드 기본 파싱 및 템플릿 메서드 패턴을 제공하는 (Abstract) 베이스 클래스 | ✅ |
| `SecurityKillSessionAction` | `AuthSession`을 쿼리하여 유저의 현재 엑세스 세션을 강제 파기 | ✅ |
| `SecurityFreezeUserAction` | 유저 레코드의 `IsFrozen` 필드를 True로 업데이트하여 로그인 영구 동결 | ✅ |
| `SecurityResetPasswordAction`| 유저의 패스워드 만료 및 초기화 메일 발송 유도 | ✅ |
| `SecurityRevokeOauthTokensAction`| 유저에게 연결된 Oauth/Connected App 접근 토큰 강제 회수 | ✅ |
| `SecurityRestrictPermissionAction`| 위험한 Permission Set Muting 처리 (동적 권한 박탈) | ✅ |
| `SecurityQuarantineProfileAction`| 유저의 Profile을 샌드박스 격리(Quarantine) 전용 프로파일로 스왑 | ✅ |
| `SecurityUserWarningAction` | 화면단 LWC 혹은 사용자 이메일로 강력한 경고 메시지 표출/발송 | ✅ |
| `SecurityCreateCaseAction` | 보안팀(SecOps) 조사를 위한 Salesforce Case(티켓) 자동 생성 | ✅ |

---

## 7. 📡 외부 알림 연동 액션 (Webhook Integration Layer)
Slack, Teams, SIEM(Splunk 등) 시스템과 외부로 통신하는 구체적인 웹훅 발송 클래스들입니다.
> **패키징 주의**: 순수 Webhook 클래스는 포함되나, 구형 프레임워크 통신 브릿지는 제외됩니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityBaseWebhookAction` | **[Flyweight]** `SecurityWebhookConfig__mdt`를 참조하여 순수 Http 뼈대를 조립 | ✅ |
| `SecurityNotifySlackAction` | 슬랙 웹훅 Endpoint로 보안 알람 발송 조치 | ✅ |
| `SecurityNotifyTeamsAction` | 마이크로소프트 팀즈 Endpoint로 적응형 카드 알람 발송 조치 | ✅ |
| `SecuritySendToSiemAction`| Syslog 혹은 Splunk/Datadog HEC Endpoint로 원시 로그 포워딩 조치 | ✅ |
| `SecurityNotifyManagerEmailAction`| 상위 관리자(Manager)에게 긴급 이메일 전문 발송 | ✅ |
| `SecurityTeamsPayloadBuilder`| `SecurityEventContext.actionButtons`를 분석해 Teams 다이나믹 버튼 카드를 렌더링 | ✅ |

---

## 8. ↩️ 양방향 소통 채널 (Inbound Action Layer)
Teams, Slack 등의 메신저에서 관리자가 "승인/차단/무시" 버튼을 눌렀을 때 응답을 받아 처리하는(Inbound) 관문입니다.

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `IInboundAction` | 외부에서 들어오는 인바운드 페이로드를 처리하는 규격 | ✅ |
| `SecurityInboundToken` | 외부 버튼 조작 시 해킹(위변조)을 막기 위한 JWT 서명/시크릿 검증 유틸 | ✅ |
| `SecurityActionInboundHandler` | 외부 노출 Site URL을 통해 건너온 Payload를 안전하게 해독하고 내부 Action으로 Routing | ✅ |

---

## 9. 🚫 레거시 및 종속 브릿지 계층 (Legacy / Excluded from Package)
과거 사내 인프라(거대 `Interface__c` 프레임워크)의 부산물이거나, 과도기적인 래핑 클래스입니다.
> **패키징 전략**: SOAR를 순수 단독앱(Managed Package)으로 추출할 때는 **절대 패키징에 포함하면 안 됩니다. (Exclude)**

| 클래스명 | 역할 및 책임 (SRP) | 패키징 |
| :--- | :--- | :---: |
| `SecurityInterfaceBridge` | 순수 SOAR를 기존 `InterfaceHandler` 버스로 태우기 위한 과도기적 중계 어댑터 | ❌ |
| `SecurityNotifyTeamsLegacyAction`| 구형 Interface 구조의 Teams 발송용 Legacy 래퍼 클래스 | ❌ |
| `InterfaceTeamsNotifier` | Interface 패키지에 소속된 구형 메일/알림 발송 유틸리티 (SOAR가 아님) | ❌ |
| `SecurityIntegrationConfig` | 구형 메타데이터 조회용 더미 클래스로 현재는 `SecurityMetadataRegistry`로 대체됨 | ❌ |

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
