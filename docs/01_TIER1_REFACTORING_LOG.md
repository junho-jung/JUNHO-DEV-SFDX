# 🚀 01. 리팩토링 및 팩토리 확장성 구축 로그 (Tier 1 Refactoring Log)

본 문서는 `05_REFACTORING_OPPORTUNITIES.md` 문서에 정의된 **Tier 1 (Critical & High ROI)** 단계의 세 가지 디자인 패턴 기반 코어 엔진 리팩토링이 성공적으로 완료되었음을 기록합니다.

---

## 🛠️ 1. SecurityActionFactory 리팩토링 (Reflection Pattern)

기존에 하드코딩된 `switch-case` 블록으로 인해 새로운 보안 액션이 추가될 때마다 개발자가 Apex 코드를 수정해야 했던 개방-폐쇄 원칙(OCP) 위반 문제를 해소했습니다.

*   **변경 사항**:
    *   `Type.forName()` 리플렉션 API를 도입하여 코드를 동적으로 인스턴스화합니다.
    *   기존의 `SecurityInboundAction__mdt` 메타데이터 스키마를 범용적으로 재활용(Action Mapping) 하도록 아키텍처를 단순화했습니다.
    *   `ExecutionMode__c` (Text형) 필드를 `SecurityInboundAction__mdt`에 새롭게 추가하여 `SYNC`/`ASYNC` 모드를 메타데이터 레벨에서 관리합니다.
*   **효과**: 향후 새로운 Teams, Slack 구조의 웹훅 액션이 수백 개 추가되더라도 **`SecurityActionFactory.cls` 코드는 단 한 줄도 수정할 필요가 없습니다.** (Zero Code 확장성의 첫걸음)

---

## 🛠️ 2. SecurityAlertHandler 리팩토링 (Chain of Responsibility)

거대한 `executeActions` 메서드 안에 중첩되어 있던 정책(Policy) 조합, Throttling(서킷 브레이커) 검사, 그리고 실제 호출(Execute) 등 **서로 다른 책임(Responsibility)** 들을 분리했습니다.

*   **변경 사항**:
    *   **`SecurityPolicyResolver.cls` 신설**: 메타데이터 정책(`SecurityPolicy__mdt`)과 임계치를 기반으로 최종 발동될 Action Type 리스트를 도출하는 전담 클래스입니다.
    *   **`ISecurityFilter` 및 `SecurityFilterChain.cls` 신설**: 요청이 엔진에 도달하기 전 선행되는 모든 검증(서킷 브레이커, Throttling 차단 등)을 플러그인 형태로 덧붙일 수 있는 디자인 패턴을 적용했습니다. (`SecurityThrottleFilter`가 첫 번째 필터로 탑재됨)
*   **효과**: Handler 본문이 극단적으로 축약되었으며, 향후 **IP 기반 블랙리스트 검사이나 권한 체크** 등의 로직을 붙일 때 기존 코드를 수정하지 않고 `FilterChain`에만 새 모듈을 끼워 넣으면 됩니다.

---

## 🛠️ 3. SecurityAlertPublisher 리팩토링 (Strategy Pattern)

`publish` 과정에서 SObject 형식을 추론하기 위해 길게 나열되어 있던 `instanceof ApiEvent`, `instanceof ReportEvent` 류의 거대한 if-else 분기문(Boilerplate) 구조를 전략 패턴으로 치환했습니다.

*   **변경 사항**:
    *   **`IEventExtractor` 인터페이스 신설**: SObject에서 ID와 Payload 데이터를 추출하는 규격(Contract) 정의.
    *   **동적 라우팅 Map 구조 도입**: `extractors` 맵 변수에 `ReportEvent.SObjectType => new ReportEventExtractor()` 형태로 사전에 주입하여, 런타임에 들어온 이벤트 타입에 맞춰 **자동으로 추출기(Extractor)가 선택**되도록 설계했습니다.
    *   `ReportEventExtractor`, `ApiEventExtractor`, `LoginEventExtractor`, `DefaultEventExtractor` 4종의 단일 책임 클래스 구축 완료.
*   **효과**: 향후 Salesforce 릴리즈에 의해 새로운 트랜잭션 이벤트(예: `ListViewEvent` 등)가 새롭게 감지 대상에 포함되더라도 메인 Publisher 코드는 건드리지 않고 **새로운 Extractor 클래스 하나만 추가**하면 완벽히 대응됩니다.

> 🚀 **확장 시뮬레이션 (Event Monitoring Coverage):**  
> 이번 Strategy Pattern 도입으로 인해 Salesforce Event Monitoring에서 제공하는 전체 트랜잭션 이벤트(예: `ListViewEvent`, `LightningUriEvent`, `DocumentAttachmentDownloads` 등)를 방어 범위에 추가하는 것이 매우 간단해졌습니다.
> 새로운 SObject 감지가 필요하다면, 기존 코드를 전혀 수정하지 않고 오직 **`IEventExtractor`를 구현한 신규 클래스 하나를 추가 생성**한 뒤, Publisher의 `extractors` Map 초기화 부분에 단 한 줄짜리 매핑(`ListViewEvent.SObjectType => new ListViewEventExtractor()`)만 끼워 넣으면 프레임워크가 완벽하게 확장됩니다.

---

> 💡 **다음 단계 (Next Steps):** Tier 1 작업이 성공적으로 컴파일됨에 따라, 구조적 기술 부채를 완전히 덜어내기 위한 **Tier 2 (퍼사드 분할, 메타데이터 레지스트리, 웹훅 액션 통폐합)** 작업으로 이행할 준비가 완료되었습니다.

---

## 🧪 부록: Tier 1 리팩토링 기능 테스트 가이드 (Manual Testing)

Tier 1 리팩토링으로 개선된 프레임워크 코어를 Salesforce Org 환경에서 직접 테스트하고 검증하시려면 다음 3가지 핵심 기능(Reflection, Chain of Responsibility, Strategy)이 정상 동작하는지 확인하시면 됩니다.

### ✅ 1. Factory의 Reflection 동적 인스턴스화 테스트 (`SecurityActionFactory`)
* **테스트 목적:** 문자열 이름만으로 정상적으로 클래스가 인스턴스화되고, 메타데이터에 정의된 실행 모드(SYNC/ASYNC)가 알맞게 반환되는지 확인합니다.
* **기대 결과:** 익명 창 반환 로그(Debug Only)에 null이 아닌 객체가 생성되고, `SecurityFreezeUserAction` 매칭이 true로 나오며, 실행 모드가 각각 `SYNC`와 `ASYNC`로 출력되어야 정상입니다.

**[종합 테스트 스크립트 (Anonymous Apex)]**
1. 개발자 콘솔을 열고 `Debug` -> `Open Execute Anonymous Window`를 클릭합니다.
2. 아래 코드를 복사해서 실행(`Execute`)합니다.
```apex
// 1. FREEZE_USER 액션이 메타데이터 기반으로 잘 생성되는지 테스트
SecurityTypes.ActionDescriptor freezeDesc = SecurityActionFactory.getAction('FREEZE_USER');
System.debug('ActionDescriptor 생성 여부: ' + (freezeDesc != null));

// 2. 클래스 타입이 맞게 캐스팅 되었는지 확인
System.debug('클래스 타입 매칭: ' + (freezeDesc.action instanceof SecurityFreezeUserAction));

// 3. ExecutionMode가 메타데이터의 설정대로 SYNC를 반환하는지 테스트
System.debug('실행 모드 (예상값 SYNC): ' + freezeDesc.mode);

// 4. 비동기 액션 테스트
SecurityTypes.ActionDescriptor slackDesc = SecurityActionFactory.getAction('NOTIFY_SLACK');
System.debug('비동기 실행 모드 (예상값 ASYNC): ' + slackDesc.mode);
```

### ✅ 2. Handler의 서킷 브레이커 & 필터 체인 테스트 (`SecurityAlertHandler`)
* **테스트 목적:** 방어 로직(Throttling)이 체인 형태로 잘 작동하여 임계치를 초과하는 과도한 이벤트 유입을 차단하는지 테스트합니다.
* **기대 결과:** SOAR 백그라운드 엔진 로그(`SecurityActionLog__c`)를 SOQL 쿼리로 조회(`SELECT Id, Status__c, Message__c FROM SecurityActionLog__c ORDER BY CreatedDate DESC`) 했을 때, 처음 N개는 정상적으로 액션이 실행되지만 임계치를 넘는 순간부터 이벤트가 차단되거나 로깅 시스템에 실패('THROTTLED' 등)가 기록되는 것이 확인되어야 합니다.

**[종합 테스트 스크립트 (Anonymous Apex)]**
```apex
List<SecurityAlert__e> testAlerts = new List<SecurityAlert__e>();

// 의도적으로 임계치 이상의 대량의 알럿을 동시에 버스에 태웁니다 (분당 제한 초과 가정)
// (주의: Org에 NIGHT_MASS_API 정책이 활성화되어 있어야 합니다.)
for(Integer i = 0; i < 20; i++) {
    testAlerts.add(new SecurityAlert__e(
        EventKey__c = 'TEST_THROTTLE_' + i,
        Source__c = 'TEST',
        PolicyCode__c = 'NIGHT_MASS_API', 
        Severity__c = 'Medium',
        UserId__c = UserInfo.getUserId()
    ));
}

// 이벤트 발행 후 Handler 작동
EventBus.publish(testAlerts);
System.debug('Published 20 alerts. Check SecurityActionLog__c for throttled results.');
```

### ✅ 3. Publisher의 다형성 추출 전략 테스트 (`SecurityAlertPublisher`)
* **테스트 목적:** 거대한 `if-else`/`instanceof` 로직이 완벽히 분리되었으며, 서로 다른 SObject 타입(ApiEvent, ReportEvent)에 대해 자동으로 적절한 Extractor 클래스가 실행되는지 확인합니다.
* **기대 결과:** 쿼리로 `SELECT EventKey__c, Payload__c FROM SecurityAlert__e`를 조회했을 때, Payload JSON 문자열 안에 Api 이벤트는 `QueriedEntities`('Account, Contact') 이메시지를, Report 이벤트는 보고서의 `Name` 데이터를 정상적으로 담고 있어야 합니다.

**[종합 테스트 스크립트 (Anonymous Apex)]**
```apex
// A. ApiEvent 타입 테스트
ApiEvent apiEvt = new ApiEvent(
        QueriedEntities = 'Account, Contact',
        Client = 'Postman'
);
SecurityAlertPublisher.publish(
        'ConsoleTest',
        'NIGHT_MASS_API', 
        'High', 
        '',
        apiEvt, 
        new User()
);

// B. ReportEvent 타입 테스트
// (주의: Org에 Report가 최소 하나 이상 존재해야 합니다.)
Report testReport = [SELECT Id, Name FROM Report LIMIT 1];
ReportEvent repEvt = new ReportEvent(
    ReportId = testReport.Id,
    Operation = 'ReportExported'
);
SecurityAlertPublisher.publish(
    'ConsoleTest',
    'DATA_EXPORT', 
    'Critical', 
    '',
    repEvt, 
    new User()
);
System.debug('Platform events published successfully bypassing all instanceof code branches.');
```
