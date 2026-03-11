# 02_TIER2_PACKAGING_STRATEGY.md (Tier 2 리팩토링 및 패키징 아키텍처)

## 🎯 개요 (Overview)
본 문서는 Salesforce SOAR(Security Orchestration, Automation, and Response) 프레임워크를 사내 종속성(예: `Interface__c` 등 자체 프레임워크)에서 분리하여, **독립적인 관리형 패키지(Managed Package)로 스케일업(Scale-up)** 하기 위해 진행된 Tier 2 아키텍처 리팩토링 내역을 기록합니다.

---

## 🏗️ 도입된 디자인 패턴 (Implemented Design Patterns)

### 1. 퍼사드 패턴 (Facade Pattern) - `SecurityGuard.cls`
과거 `SecurityGuard`는 모든 이벤트를 하나의 비대한 메서드(`handleSecurityEvent`)로 처리하는 파사드(God Class) 안티 패턴의 위험이 있었습니다.
* **Refactoring:** 이벤트 맥락(Event Context)별 전용 분석 메서드(`analyzeApiEvent`, `analyzeReportEvent`, `analyzeListViewEvent`)를 전진 배치하여 진정한 퍼사드 패턴을 완성했습니다.
* **Benefit:** 
  * 인터셉터(`EM_SecurityBlockInterceptor` 등) 로직이 극적으로 단순해졌습니다. 단순 if-else 늪에서 벗어나, `SecurityGuard`에게 타입별 평가를 위임하기만 하면 됩니다.
  * 신규 보안 규칙이 추가되더라도 `SecurityGuard`의 해당 이벤트 메서드만 수정하면 되므로 결합도가 매우 낮아졌습니다.

### 2. 싱글톤 패턴 (Singleton Pattern) - `SecurityMetadataRegistry.cls`
이전에는 메타데이터에 의존성이 높아질수록 동일 트랜잭션 내에서 중복 SOQL 쿼리(`SecurityPolicy__mdt`, `SecurityInboundAction__mdt` 등)가 발생하는 문제가 있었습니다.
* **Refactoring:** 트랜잭션 수명 주기 내에서 메모리를 보호하는 전역 레지스트리를 신설하여 단 한 번의 SOQL 쿼리로 핵심 정책을 로드·캐싱합니다.
* **Benefit:**
  * SOQL Limits 안정을 담보합니다. 커스텀 인터페이스가 복잡해져도 쿼리 횟동(1~2회)이 보장됩니다.
  * 추후 AppExchange 패키징 시, 고객사가 자체 오버라이드 룰을 적용할 때 이 레지스트리 단에서 분기 처리만 해주면 내부 로직을 건드릴 필요가 없습니다.

### 3. 플라이웨이트 패턴 (Flyweight Pattern) - `SecurityBaseWebhookAction.cls`
가장 큰 이슈였던 외부 시스템 통신 종속성 문제를 해결했습니다. 기존 `SecurityNotifySlackAction`, `TeamsAction` 등은 사내 범용 통신 객체인 `Interface__c`와 강결합되어 있어 패키지만 떼어내어 배포할 수 없었습니다.
* **Refactoring:** Sfdx 표준 지원 범주인 `HttpRequest`와 `Named Credentials`를 사용하는 공통 가벼운(Flyweight) 뼈대 클래스 `SecurityBaseWebhookAction`를 만들고, 모든 웹훅 액션이 이를 상속받도록 수정했습니다.
* **Benefit:**
  * **Zero Dependency:** 더 이상 커스텀 인터페이스 객체(`Interface__c`)나 사내 프레임워크에 의존하지 않으므로 ISV 패키징 시 즉각 독립 배포가 가능해졌습니다.
  * 웹훅 엔드포인트는 `SecurityIntegration__mdt.InterfaceId__c` 필드를 참조하며, 이곳에 Salesforce 표준 `Named Credential` 명칭을 기재하도록 설계되었습니다.

---

## 🚀 추가 적용점 및 효과 (Key Takeaways)

1. **독립성 확보 (Decoupled Framework):**
    * 이벤트 수동 파싱, 외부 통신 로직, 런타임 캐싱 계층이 모두 책임을 나눠 갖음으로써, Sfdx 네임스페이스를 씌워 `1GP/2GP 관리형 패키지`로 즉시 빌드할 수 있는 토대가 마련되었습니다.
2. **모니터링 & 대응 확장:**
    * 기존의 Tier 1 (Strategy, Reflection) 패턴과 시너지를 일으켜, 사용자는 코드 한 줄 건드리지 않고도 **동적 이벤트 추출 ➡️ 동적 액션 할당 ➡️ 정책 오버라이드 ➡️ 무종속성 외부 알림 발송** 까지 일련의 SOAR 흐름을 자유롭게 커스터마이징 가능합니다.

---

### 개발 로그 (Changelog)
* **Date:** 2026-03-11
* **Author:** jh.jung (AI Assisted)
* **Status:** Tier 2 Refactoring Completed. Ready for independent managed package evaluation.

---

## 🧪 테스트 가이드 (How to Test)
Tier 2 리팩토링으로 적용된 3가지 핵심 패턴이 정상 작동하는지 검증하기 위한 가이드입니다.

### 1. 퍼사드 패턴 (Facade) 검증
* **테스트 목적:** `SecurityGuard`의 이벤트별 분리된 파사드 메서드들이 기존과 동일하게 위협을 정확히 차단/감지하는지 확인합니다.
* **실행 방법:**
  1. (Block) 일반 사용자로 로그인하여 `Account` 등 주요 오브젝트에서 100건 이상의 데이터를 Dataloader나 API로 요청합니다. (NIGHT_API_HEIST 또는 MASS_DATA_EXPORT 정책 발동 여부 확인)
  2. (Monitor) 보안 대상이 아닌 일반 보고서를 조회하거나, 토큰 재사용 의심 상황을 연출합니다.
  3. `SecurityActionLog__c` 레코드가 정상 생성되고, `SecurityGuard`가 평가한 등급(CRITICAL/HIGH/LOW)이 정확히 매핑되었는지 확인합니다.

### 2. 싱글톤 패턴 (Singleton) 검증
* **테스트 목적:** `SecurityMetadataRegistry`가 메타데이터 쿼리를 메모리에 올바르게 캐싱하여 추가적인 SOQL Limits를 소모하지 않는지 확인합니다.
* **실행 방법:**
  1. 익명 Apex 창(Developer Console)에서 이벤트를 3~5회 연속으로 발행하는 스크립트를 실행합니다.
  2. `System.Limits.getQueries()` 로그를 추적하여, 이벤트 개수와 무관하게 `SecurityPolicy__mdt` 및 `SecurityInboundAction__mdt`에 대한 쿼리가 트랜잭션당 단 **1회**만 발생했는지 검증합니다.

### 3. 플라이웨이트 패턴 (Flyweight) 검증
* **테스트 목적:** 기존 `Interface__c`를 제거한 웹훅 액션이 표준 `HttpRequest` 및 `Named Credentials`를 통해 정상적으로 알림을 발송하는지 확인합니다.
* **실행 방법:**
  1. `SecurityIntegration__mdt` 리스트에서 ActionType이 `NOTIFY_SLACK` 혹은 `NOTIFY_TEAMS`인 레코드의 `InterfaceId__c` 필드에 유효한 콜아웃 주소(예: `callout:MySlackWebhookCore` 또는 직접적인 HTTPS URL)를 입력합니다.
  2. 고위험(CRITICAL) 보안 이벤트를 강제로 발생시킵니다 (예: 권한 상승 목적의 SOQL 실행).
  3. 실제 Slack/Teams 채널로 경보 메시지가 수신되는지 확인합니다.
  4. 만약 실패하더라도 `SecuritySoarTrace` 객체나 Apex Debug Log에서 HTTP Status Code와 Response 내용을 확인하여 오류를 추적할 수 있습니다.
### 4. 종합 테스트 스크립트 (Anonymous Apex)
Developer Console의 Anonymous Window 창에 아래 코드를 복사해서 실행하면, 한 번의 트랜잭션으로 위의 3가지 패턴이 모두 정상 동작하는지 테스트할 수 있습니다. 정상 동작할 경우, `SecurityActionLog__c` 레코드 생성과 함께 설정된 외부 시스템(Slack/Teams)으로 알림 전송이 시도됩니다.

```apex
// 1. 임의의 심각도 높은 ApiEvent 모의 생성 (NIGHT_API_HEIST / PRIVILEGE_ESCALATION 유도)
ApiEvent mockEvent = new ApiEvent(
    Query = 'SELECT Id, Password FROM User', 
    RowsProcessed = 500,
    SourceIp = '1.2.3.4',
    Client = 'Postman'
);

// 2. 현재 로그인된 유저 정보 로드
User currentUser = [SELECT Id, Name, Email, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

// 3. Facade 패턴이 적용된 Publisher 호출 (내부적으로 SecurityGuard의 analyzeApiEvent가 발동됨)
// 3-1. 첫 번째 시도 (싱글톤 레지스트리에 의해 메타데이터가 메모리에 로드됨)
System.debug('=== First Call (Metadata Initialization) ===');
Integer queriesBefore = Limits.getQueries();
SecurityAlertPublisher.publish(
    'EM_SecurityBlockInterceptor', // Source
    'PRIVILEGE_ESCALATION',        // PolicyCode
    'CRITICAL',                    // Severity
    'NOTIFY_SLACK',                // ActionType (Flyweight 웹훅 액션이 트리거됨)
    mockEvent,                     // Raw Event
    currentUser                    // Target User
);
System.debug('Queries used: ' + (Limits.getQueries() - queriesBefore));

// 3-2. 두 번째 시도 (동일 트랜잭션 - 캐시 히트 검증)
System.debug('=== Second Call (Cache Hit Expected) ===');
queriesBefore = Limits.getQueries();
SecurityAlertPublisher.publish(
    'EM_SecurityBlockInterceptor',
    'NIGHT_API_HEIST',
    'HIGH',
    'NOTIFY_TEAMS',               // ActionType
    mockEvent,
    currentUser
);
System.debug('Queries used (Should be significantly lower/zero): ' + (Limits.getQueries() - queriesBefore));
```
