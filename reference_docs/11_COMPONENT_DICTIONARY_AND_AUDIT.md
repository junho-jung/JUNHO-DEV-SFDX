# 📚 11. 전체 컴포넌트 사전 및 네이밍 감사 (Component Dictionary & Audit)

본 문서는 Security SOAR 프레임워크를 구성하는 **모든(`Security*`, `Interface*`, `EM_*`) Apex 클래스, 커스텀 오브젝트, 커스텀 메타데이터**를 단 하나도 빠짐없이 나열한 '통합 인덱스(Dictionary)' 입니다. 

각 컴포넌트가 현재 수행하는 역할과 이름이 정확히 일치하는지(✨**정상 유지**) 아니면 리팩토링 과정에서 이름 변경이 필요한지(🔨**리네이밍 필요**) 여부를 상태값으로 표현하여, 프레임워크 전체의 네이밍 컨벤션 무결성을 검증합니다.

---

## 1. ⚙️ 메타데이터 & 데이터 모델 (Metadata & Objects)

| 구분 | 컴포넌트명 (As-Is) | 종류 | 역할 요약 | 상태 | 💡 To-Be (필요 시) |
| :--- | :--- | :--- | :--- | :---: | :--- |
| **코어** | `SecurityPolicy__mdt` | Metadata | 위협 트리거 조건(Threshold) 및 액션 등급 정의 마스터. | ✨정상 | - |
| **코어** | `SecurityInboundAction__mdt` | Metadata | 인바운드 웹훅 요청에 대한 Target Apex Class 매핑. | ✨정상 | - |
| **코어** | `SecurityActionRequest__e` | Event | 권한 이관(Privilege Escalation)을 위한 DML 비동기 위임 이벤트 버스. | ✨정상 | - |
| **코어** | `SecurityAlert__e` | Event | TxnSecurity 트리거로부터 떨어져 나온 메인 이벤트 스트림 버스. | ✨정상 | - |
| **설정** | `SecurityInboundConfig__mdt` | Metadata | 글로벌 킬 스위치 및 아웃바운드 폭주 제어(Throttling), 토큰 설정 통합 관리. | 🔨변경 | `SecurityGlobalConfig__mdt` |
| **설정** | `SecurityIntegration__mdt` | Metadata | ActionType을 특정 큐(Mode)와 대상 인터페이스(Id)로 라우팅하는 매핑 레코드. | 🔨변경 | `SecurityActionRoute__mdt` |
| **설정** | `InterfaceConfig__mdt` | Metadata | 외부 Callout(Named Credential, Endpoint URL)을 위한 순수 HTTP 통신 규격. | 🔨변경 | `HttpCalloutConfig__mdt` |
| **로그** | `SecurityAuditLog__c` | SObject | 유저별 위협 발생 카운트 및 누적 상태(AlertCount 등)를 기록하는 저장소. (State 본체) | 🔨변경 | `SecurityUserState__c` |
| **로그** | `SecurityActionLog__c` | SObject | 시스템이 특정 유저를 대상으로 실행한 액션(차단, 알림 등)의 결과 로그. | ✨정상 | - |
| **로그** | `InterfaceLog__c` | SObject | 실제 HTTP 웹 Callout 전송 텍스트와 성공/실패 여부를 담는 로그. | 🔨변경 | `HttpCalloutLog__c` |

---

## 2. 🛡️ 코어 엔진 및 정책 평가 (Core Engine & Evaluator)

| 컴포넌트명 (As-Is) | 종류 | 역할 요약 | 상태 | 💡 To-Be (필요 시) |
| :--- | :--- | :--- | :---: | :--- |
| `EM_SecurityBlockInterceptor.cls` | Apex | 트랜잭션 보안 트리거(Event Monitoring)에서 데이터 다운로드/로그인 즉시 차단 여부 평가. | ✨정상 | - |
| `EM_SecurityMFAInterceptor.cls` | Apex | 트랜잭션 보안 시그널 중 MFA 강제 요구 로직 통제. | ✨정상 | - |
| `EM_SecurityMonitorInterceptor.cls` | Apex | 차단이 아닌 단순 로깅/관제용 시그널 감지 인터셉터. | ✨정상 | - |
| `SecurityAlertHandler.cls` | Apex | SecurityAlert__e 이벤트를 수신하여 정책 평가 및 액션을 오케스트레이션 하는 메인 핸들러. | ✨정상 | - |
| `SecurityAlertPublisher.cls` | Apex | 트랜잭션 보안 트리거 안에서 Platform Event 플랫폼 버스로 알럿을 토스 발송. | ✨정상 | - |
| `SecurityAlertFallbackJob.cls` | Apex | 알릿 이벤트 발송 실패 시 재시도 또는 Fallback 큐 라우팅. | ✨정상 | - |
| `SecurityGuard.cls` | Apex | 메타데이터 캐싱, 임계치 시간 계산 등 모든 정책을 결정짓는 중앙 뇌(Brain). (너무 크기 때문에 쪼개야 함) | 🔨변경 | `SecurityPolicyEvaluator.cls` |
| `SecurityValidator.cls` | Apex | LWC, 외부 API 등에서 접근 권한 및 관리자 예외 등을 가볍게 체크하는 유틸리티. | 🔨변경 | `SecurityAccessChecker.cls` |
| `SecurityActionThrottle.cls` | Apex | 분당 일정 횟수 이상 동일 액션의 발송을 방어하는 서킷 브레이커. | ✨정상 | - |
| `SecurityKillSwitch.cls` | Apex | 비상 가동 중단(Kill) 스위치 유틸리티. | ✨정상 | - |

---

## 3. 💥 액션 엔진 및 팩토리 (Action Factory & Executor)

| 컴포넌트명 (As-Is) | 종류 | 역할 요약 | 상태 | 💡 To-Be (필요 시) |
| :--- | :--- | :--- | :---: | :--- |
| `ISecurityAction.cls` | Interface | 모든 액션 구현체가 필수 도출해야 하는 공통 Strategy 인터페이스. | ✨정상 | - |
| `SecurityActionExecutor.cls` | Apex | 평가가 끝난 Action들을 최종 Execute 하거나 Bulk Queueable로 묶어 송신하는 실행기. | ✨정상 | - |
| `SecurityActionRequest_tr.cls` | Apex | 권한 이관 이벤트(SecurityActionRequest__e) 수신 트리거 핸들러. | ✨정상 | - |
| `SecurityBaseAction.cls` | Apex | 액션들의 공통 행위(가상 메서드)를 상속해주는 부모 클래스. | ✨정상 | - |
| `SecurityTypes.cls` | Apex | Action Descriptor 등 프레임워크 전반의 Wrapper 데이터 타입 관리. | ✨정상 | - |
| `SecuritySoarTrace.cls` | Apex | 프레임워크 라이프사이클 마이크로 트레이싱 로그 유틸. | ✨정상 | - |
| `SecurityActionFactory.cls` | Apex | 분기문(`switch`)을 통해 Action 클래스를 생성. (향후 리플렉션으로 개선) | 🔨변경 | `SecurityActionBuilder.cls` |
| `SecurityInterfaceBridge.cls` | Apex | 팩토리가 찍어낸 Action의 전송 방식을 비동기(Async) 등으로 전환 및 분배하는 브릿지. | 🔨변경 | `SecurityActionDispatcher.cls` |

### ⚡ 구현된 액션 클래스들 (Action Implementations)
*(아래 액션들은 패턴과 목적이 명확하여 모두 **✨정상 유지** 대상입니다.)*
* `SecurityFreezeUserAction.cls`: 사용자 계정 동결 조치
* `SecurityKillSessionAction.cls`: 현재 활성화된 세션 강제 종료
* `SecurityResetPasswordAction.cls`: 비밀번호 초기화 메일 발송
* `SecurityRestrictPermissionAction.cls`: 권한셋(Permission Set) 박탈
* `SecurityRevokeOauthTokensAction.cls`: OAuth 연동 즉시 해지
* `SecurityUserWarningAction.cls`: 유저에게 Salesforce 내부 알림 송신
* `SecurityQuarantineProfileAction.cls`: 유저 프로필 강제 격리 프로필로 변환
* `SecurityCreateCaseAction.cls`: 보안 부서 대응을 위한 티켓(Case) 생성
* `SecurityNotifySlackAction.cls`: 슬랙 전송
* `SecurityNotifyTeamsAction.cls`: 마이크로소프트 팀즈 전송
* `SecurityNotifyManagerEmailAction.cls`: 소속 그룹장 이메일 발송
* `SecuritySendToSiemAction.cls`: Splunk 등 외부 SIEM 장비로 UDP/HTTP 전파
* `SecurityNotifyUtil.cls`: 알림 메시지 문자열 조합 유틸 서포터

---

## 4. 🌐 통신 및 인바운드 인터페이스 (Http Callout & Inbound)

| 컴포넌트명 (As-Is) | 종류 | 역할 요약 | 상태 | 💡 To-Be (필요 시) |
| :--- | :--- | :--- | :---: | :--- |
| `IInboundAction.cls` | Interface | 인바운드 요청을 받을 대상 클래스가 가져야 할 인터페이스. | ✨정상 | - |
| `IInterfaceExecutor.cls` | Interface | 외부 통신 클래스가 가져야 할 규격 인터페이스. | 🔨변경 | `IHttpCalloutExecutor.cls` |
| `SecurityActionInboundHandler.cls` | Apex | Slack/Teams에서 들어오는 양방향 버튼 웹훅 수신 REST API 게이트웨이. | ✨정상 | - |
| `SecurityInboundToken.cls` | Apex | 인바운드 승인/거절 버튼의 1회성 토큰(JWT/JTI) 검증 유틸리티. | ✨정상 | - |
| `SecurityPrivilegeEscalator.cls` | Apex | Guest 유저의 인바운드 컨텍스트를 `without sharing`으로 승격하여 SObject 업데이트 우회 실행. | ✨정상 | - |
| `InterfaceBizInfo.cls`<br>`InterfaceBatchBizInfo.cls`<br>`InterfaceQueueableBizInfo.cls` | Apex | 통신 시 주고받는 데이터 직렬화/역직렬화용 DTO(Data Transfer Object) 클래스 모음 | 🔨변경 | `HttpCalloutDTO.cls` |
| `InterfaceFactory.cls` | Apex | Config 설정값(Named Credential 등)을 실제 Callout 객체에 주입하는 팩토리. | 🔨변경 | `HttpCalloutFactory.cls` |
| `InterfaceHandler.cls` | Apex | 시스템 표준 `HttpRequest`, `HttpResponse`를 핸들링하는 네이티브 HTTP 래퍼. | 🔨변경 | `HttpCalloutHandler.cls` |
| `InterfaceBatch.cls` | Apex | 한 번에 처리해야 할 통신 대상(Chunk)이 많을 때 사용하는 Database.Batchable 모드. | 🔨변경 | `HttpCalloutBatch.cls` |
| `InterfaceQueueable.cls` | Apex | Limits(101) 회피를 위해 묶어서(Bulk) 던지는 System.Queueable Callout 모드. | 🔨변경 | `HttpCalloutQueueable.cls` |
| `InterfaceRealTime.cls` | Apex | 동기 컨텍스트에서 즉시 외부 네트워크로 쏘는 Callout 모드. | 🔨변경 | `HttpCalloutRealTime.cls` |

---

## 📌 결론 (Audit Summary)

수십여 개에 달하는 SOAR 관련 컴포넌트를 전수 조사한 결과, 다음 사실을 도출했습니다.

1. **내부 액션 로직이나 트리거 방어벽(EM_*, Security*Action 등)** 은 디자인 패턴(Strategy, Factory, Interceptor) 설계에 맞춰 **매우 아름답고 완벽한(✨정상)** 네이밍을 가지고 있습니다.
2. 반면 네이밍 부채(🔨변경 필요)는 주로 **(1) 너무 방대한 책임을 지게 된 정책 통제소(`SecurityGuard`)** 와 **(2) HTTP 통신을 모호하게 표현한 `Interface` 관련 클래스/메타데이터 그룹** 에서 집중적으로 발생했습니다.

본 통합 딕셔너리(11번 문서)는 프레임워크 전체 구성 요소에 대한 지도(Map) 역할을 하며, 리팩토링 담당자는 오직 '🔨변경' 마크가 붙은 컴포넌트의 이름과 스키마 구조만 `To-Be` 방향으로 교체하면 프레임워크의 유지보수 무결성을 100% 달성하게 됩니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
