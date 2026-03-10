# 💻 03. 개발 파트 (Technical Development)

본 문서는 Security SOAR 프레임워크의 코어 심층부(Core Deep-dive)를 다룹니다. 시스템 아키텍트와 백엔드 개발자가 클래스 호출 메커니즘을 상세히 추적하고 확장(Scaling) 방법을 파악하기 위한 가이드입니다.

---

## 1. 프레임워크 상세 동작 메커니즘 (메소드 레벨 호출 추적)

전체 보안 자동화 파이프라인은 크게 **①이벤트 캡처**, **②정책 판별**, **③액션 실행**, **④외부 인바운드/수동 개입**의 4가지 대분류로 나뉘며, 각 단계별 트랜잭션과 호출 메소드는 다음과 같이 동작합니다.

### ① 이벤트 캡처 단계 (Event Detection)
Transaction Security가 발동할 때 동기적(Synchronous)으로 수행되는 가장 앞단의 방어벽입니다. 이 단계는 트랜잭션 처리량 제약사항으로 비동기 호출이나 DML이 제한됩니다.

* **1-1. `BaseInterceptor.evaluate(SObject event)`**
  * Salesforce의 EventCondition이 트리거되면 최초로 호출됩니다.
  * 내부적으로 `EM_***Interceptor` 들의 패턴 순회(`doEvaluate()`)를 반복합니다.
* **1-2. `EM_SecurityBlockInterceptor.doEvaluate(event, user)`**
  * `SecurityGuard.isPrivilegeEscalation(query)` 등 세부 유틸리티를 호출하여 쿼리를 텍스트 기반으로 분석하거나 Report 사이즈를 계산합니다.
  * 즉각 차단(Block) 조건 충족 시 `InterceptorResult('PRIVILEGE_ESCALATION', 'CRITICAL')`를 리턴합니다.
* **1-3. `SecurityAlertPublisher.publish(String policyCode, ...)`**
  * 인터셉터 내부적인 Callout 블록이나 DML 예외를 우회하기 위해 Platform Event(`SecurityAlert__e`)를 Fire(발행)합니다. 실제 SOAR 조치는 이 비동기 버스에 올라타면서 시작됩니다.

### ② 정책 판별 단계 (Policy & Orchestration)
발행된 이벤트를 큐에서 꺼내어 분석하고 어떤 조치 파이프라인(Factory)을 태울지 결정합니다.

* **2-1. `SecurityAlertHandler.processAlerts(List<SecurityAlert__e>)`**
  * `SecurityAlert_tr` 트리거에서 리스트를 넘겨받아 배치로 평가 사이클을 개시합니다.
* **2-2. `SecurityAlertHandler.executeActions(AlertRecord alert)`**
  * `SecurityPolicy__mdt` 메타데이터를 쿼리하여 이벤트의 `PolicyCode__c`(예: `PRIVILEGE_ESCALATION`)와 일치하는 정책을 캐싱하고 매핑합니다.
  * `SecurityActionThrottle.isThrottled(...)`를 호출하여 1분 내에 동일 유저/동일 조치가 한도(Threshold)를 넘지 않았는지 체크합니다. (무한 슬랙 알림 방어용 서킷 브레이커)
* **2-3. `SecurityActionFactory.create(String actionType)`**
  * 정책에 맵핑된 `ActionTypes__c`(예: `NOTIFY_SLACK,KILL_SESSION`) 문자열을 Parsing하여 루프를 돌며 `ISecurityAction` 인터페이스를 구현한 구체적 클래스의 인스턴스 배열을 동적 생성하여 반환합니다.

### ③ 공통 액션 실행 단계 (Action Execution)
오케스트레이터로부터 넘겨받은 액션 인스턴스 팩토리를 구동하고, 감사 로그(Audit Log)를 남깁니다.

* **3-1. `SecurityActionExecutor.executeWithLogging(ISecurityAction action, String payload, Boolean isSync)`**
  * 모든 액션 실행을 조율하는 핵심 엔진입니다.
  * `ISecurityAction.isAsync()` 결과값(어떤 액션이 Http Callout 등을 포함하는지)에 따라 동기 실행(`action.execute()`) 혹은 비동기 큐 대기(`SecurityActionExecutor.startAsyncContext()`) 상태로 라우팅을 분배합니다.
* **3-2. `SecurityBaseAction.execute(String payloadJson)` & 내부 `doExecute()`**
  * 모든 액션은 상속구조를 가지며 `BaseAction`의 템플릿 메서드 패턴(Template Method Pattern)에 의해 페이로드 파싱 등 보일러플레이트 코드 제어 후 하위 `doExecute()`를 호출합니다.
  * **(예 1) 로컬 조치:** `SecurityKillSessionAction.doExecute()` 내부에서는 `AuthSession`을 쿼리하고 SessionId를 파기합니다. System 권한 실행을 요구할 수 있습니다.
  * **(예 2) 외부 조치:** `SecurityNotifySlackAction.doExecute()` 내부에서는 `SecurityIntegration__mdt`를 뒤져 Endpoint를 찾고 Http Callout을 수행합니다.
* **3-3. `SecuritySoarTrace.log(String location, String jsonData)`**
  * 각 Action이 끝날 때 성공/오류 메시지 등 전체 스택 트레이스를 `SecurityActionLog__c` 객체에 DML로 Insert 합니다.

### ④ 확장 흐름: 웹훅 인바운드 및 대시보드 개입 제어
경고 알림을 본 보안팀의 수동 판단이나, 시스템 외부에서의 응답이 어떻게 다시 내부 파이프라인과 결합되는지 설명합니다.

* **상황 A: Slack/Team 등 외부 시스템의 Inbound Webhook (승인/거절 콜백)**
  * **`SecurityActionInboundHandler.resolveInboundAction(String action)`**
    * Slack 메세지의 "계정 정지 위임" 버튼을 누를 경우 Payload HTTP POST 요청이 유입됩니다.
    * `SecurityInboundToken.isRequestFromAllowedOrigin()` 및 `generateEncryptedToken()`을 통해 서명과 타임스탬프 제한 시간(TTL)을 검증합니다.
    * 통과 시 `SecurityInboundAction__mdt`에서 매핑된 `FREEZE_USER` 액션(`SecurityFreezeUserAction`)을 찾아내어 곧바로 **`SecurityActionExecutor.execute()`**를 강제 호출합니다.

* **상황 B: 관리자의 대시보드 강제 개입 조치 (Dashboard Override)**
  * **`SecurityDashboardController.executeManualAction(String actionType, String payload)`**
    * LWC 화면에서 보안 로그를 대조하던 관리자가 수동으로 "수동 격리 해제"나 "비밀번호 초기화"를 클릭합니다.
    * 컨트롤러는 중간 Handler를 건너뛰고 직통으로 **`SecurityActionFactory`**를 수동 조작하여 **`SecurityActionExecutor`**에 태워 액션을 강제 실행시킵니다.

* **상황 C: 권한 상승 대리 실행 기법 (Privilege Escalation Wrapper)**
  * **`SecurityPrivilegeEscalator.executeAsSystem(String actionType, String payload)`**
    * 일반 사용자가 웹훅을 트리거하거나 시스템 프로세스를 진행 중일 때, User Freeze나 Session Kill 같은 조작은 System Admin 권한이 필수적입니다.
    * 권한 에러 방지를 위해, 이 헬퍼 클래스는 `SecurityActionRequest__e` 시스템 Platform Event를 발행하여 System Context를 획득하고 `SecurityActionRequest_tr` 내에서 System Mode 런타임으로 다시 **`SecurityActionExecutor`**를 태워 권한 이슈를 완전히 격리(우회)합니다.

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
