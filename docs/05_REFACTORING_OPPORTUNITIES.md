# 🛠️ 05. 디자인 패턴 기반 리팩토링 제안 (Refactoring Opportunities)

본 문서는 현재 Security SOAR 프레임워크의 코드를 더 짧고, 알아보기 쉽고, 확장성 있게(Extensible) 개선하기 위해 **디자인 패턴을 적용할 수 있는 10가지 리팩토링 포인트**를 딥다이브(Deep-dive) 형식으로 서술합니다. 

특히 즉각적인 아키텍처 개선 효과가 탁월한 순서(**중요도 및 시급성**)대로 3개의 Tier로 세분화하여 배치하였습니다. 이 문서는 향후 진행될 실제 리팩토링 개발의 핵심 설계서(Blueprint)로 활용됩니다.

---

## 📊 리팩토링 우선순위 매트릭스 (Priority Matrix)

| Tier | 우선순위 | 리팩토링 대상 클래스 | 도입할 디자인 패턴 | 해결되는 핵심 문제 | 시급성 |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **Tier 1** | **1. 팩토리 동적 생성** | `SecurityActionFactory` | **Reflection** | OCP 위배 (끝이 없는 분기문 하드코딩) | 🔥 매우 높음 |
| **Tier 1** | **2. 서킷 브레이커 추출** | `SecurityAlertHandler` | **Chain of Responsibility** | 핵심 오케스트레이션 로직의 비대화 | 🔥 매우 높음 |
| **Tier 1** | **3. 이벤트 추출 다형성** | `SecurityAlertPublisher` | **Strategy** | SObject 타입별 방대한 분기 처리 | 🔥 매우 높음 |
| **Tier 2** | **4. 거대 유틸리티 분할** | `SecurityGuard` | **Facade / SRP** | 350라인 이상의 God Class (결합도 극상) | ⭐ 높음 |
| **Tier 2** | **5. 메타데이터 중앙 제어** | `Security*` 전역 | **Registry / Singleton** | 산발적인 SOQL 조회 및 캐싱 부재 | ⭐ 높음 |
| **Tier 2** | **6. 웹훅 액션 통폐합** | `SecurityNotify*Action` | **Flyweight** | 내부가 똑같은 무의미한 클래스 양산 | ⭐ 높음 |
| **Tier 3** | **7. 객체 조립 캡슐화** | `SecurityAlertPublisher` | **Builder** | 이벤트 Payload 파라미터 팽창 및 가독성 저하 | 💡 보통 |
| **Tier 3** | **8. 로깅 부가기능 추가** | `SecurityActionExecutor` | **Decorator** | 재시도/외부로깅 등 덧붙일 때 엔진 본문 수정 | 💡 보통 |
| **Tier 3** | **9. 보안 검증 규격화** | `SecurityValidator` | **Specification** | 복합 검증 조건이 하드코딩되어 재사용 불가 | 💡 보통 |
| **Tier 3** | **10. 인바운드 중앙 제어**| `SecurityActionInboundHandler` | **Proxy / Front Controller**| 채널(Slack 등) 증가 시 보안 검증 로직 중복 | 💡 보통 |
| **Tier 3** | **11. 로깅 아키텍처 연동**| `SecuritySoarTrace` | **Observer** | System.debug에 묶여 외부 매체 연동이 어려움 | 💡 보통 |
| **Tier 4** | **12. Zero-Code 무코딩 확장성**| 전역 아키텍처 | **Universal/Template Pattern** | 17번 문서 - 정책/액션 추가 시 Apex 코딩 필요 | 💡 궁극 (Ultimate) |
| **Tier 4** | **13. 패키징 캡슐화와 접근 제어**| 엔진 코어 & 인터페이스 | **Visibility Control** | 18번 문서 - ISV 배포 시 코어 소스 노출 방어 | 💡 궁극 (Ultimate) |

---

# 🥇 Tier 1 : Critical & High ROI (즉시 전환 시 효과 극대화)

## 1. 개방-폐쇄 원칙(OCP)을 위한 동적 팩토리 (Reflection Pattern)

현재 `SecurityActionFactory.cls`는 새로운 액션이 추가될 때마다 코드를 직접 수정해야 하는 구조적 한계(OCP 원칙 위배)를 가지고 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
`switch on formattedType` 구문이 하드코딩되어 있습니다. 새로운 조치(예: `NOTIFY_DISCORD`)가 기획되면, 개발자는 무조건 Factory 클래스의 본문을 열어서 `when 'NOTIFY_DISCORD' { return new SecurityNotifyDiscordAction(); }`를 타이핑하고 다시 배포해야 합니다.

### 🟢 리팩토링 제안 (To-Be)
Salesforce의 **Reflection API (`Type.forName()`)** 패턴을 활용합니다.
`SecurityAction__mdt` 같은 커스텀 메타데이터에 `ActionType(KILL_SESSION)`과 `ClassName(SecurityKillSessionAction)` 매핑을 저장합니다.

```apex
// To-Be: 동적 객체 생성 (코드가 완전히 축약되며, 확장에 열려있음)
public static SecurityTypes.ActionDescriptor getAction(String actionType) {
    // 1. 메타데이터에서 클래스명 조회
    SecurityActionMapping__mdt mapping = [SELECT ActionClassName__c, ExecutionMode__c 
                                          FROM SecurityActionMapping__mdt 
                                          WHERE ActionType__c = :actionType LIMIT 1];
    
    // 2. 클래스 이름을 기반으로 인스턴스 동적 생성 (Reflection)
    Type t = Type.forName(mapping.ActionClassName__c);
    ISecurityAction actionInstance = (ISecurityAction) t.newInstance();
    
    return new SecurityTypes.ActionDescriptor(actionInstance, mapping.ExecutionMode__c);
}
```
**✨ 기대 효과**: 팩토리 클래스의 코드가 10줄 이내로 극단적으로 짧아지며, 향후 100개의 액션이 추가되어도 Apex 코드는 단 1줄도 수정할 필요가 없습니다.

---

## 2. 서킷 브레이커 및 로직 추출 (Chain of Responsibility / Composition)

`SecurityAlertHandler.cls` 내부의 `executeActions()` 메서드는 하나의 함수 안에 1) 정책 결합, 2) 임계치 다운그레이드 체크, 3) 스로틀링 컷오프(Circuit Breaker), 4) 팩토리 호출 로직이 길게 섞여 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
함수 하나의 크기가 너무 비대해져서 디버깅이 어렵고, 새로운 검사 조건(예: IP 기반 블랙리스트 검사)이 들어오면 또다시 복잡한 `if-else` 블록을 뚫고 들어가 코드를 짜야 합니다.

### 🟢 리팩토링 제안 (To-Be)
**책임 연쇄 패턴(Chain of Responsibility)** 이나 필터(Filter) 패턴을 도입합니다. 리스트에 검사기(Validator)들을 순서대로 밀어넣고 통과하는지 지켜봅니다.

```apex
// To-Be: 핸들러는 오직 '오케스트레이션' 에만 집중
private static void executeActions(AlertRecord alert, Decimal alertCount) {
    // 1. 정책 수집
    Set<String> actionTypes = PolicyResolver.mergePolicies(alert, alertCount);
    
    // 2. 실행 파이프라인 (책임 연쇄)
    for (String aType : actionTypes) {
        // 필터 체인을 통과하지 못하면 스킵 (스로틀링, 블랙리스트 등)
        if (!SecurityFilterChain.isAllowed(alert, aType)) {
            continue; 
        }
        
        // 3. 실제 실행
        ISecurityAction action = SecurityActionFactory.getAction(aType);
        SecurityActionExecutor.execute(action, ...);
    }
}
```
**✨ 기대 효과**: 핵심 배치가 진행되는 Handler 클래스의 코드가 굉장히 간결해지며, 런타임 제약(제한, IP 검사 등) 로직을 언제든 뗐다 붙일 수 있는 플러그인(Plug-in) 아키텍처가 됩니다.

---

## 3. 이벤트 추출기의 다형성 확보 (Strategy / Adapter Pattern)

`SecurityAlertPublisher.cls` 내부의 `extractResourceInfo()` 메소드는 이벤트 유형별로 분기하는 거대한 `If-Else` 체인을 가집니다.

### 🔴 현재 코드의 문제점 (As-Is)
TxnSecurity 이벤트 종류(`ReportEvent`, `ApiEvent`, `LoginEvent`, `ListViewEvent`)가 늘어날 때마다 분기문이 계속 추가됩니다.

```apex
// As-Is: 타입 검사(instanceof)와 다운캐스팅의 파티
if (rawEvent instanceof ReportEvent) {
    ReportEvent re = (ReportEvent) rawEvent; ...
} else if (rawEvent instanceof ApiEvent) {
    ApiEvent ae = (ApiEvent) rawEvent; ...
} else if (rawEvent instanceof LoginEvent) {
    // ...
}
```

### 🟢 리팩토링 제안 (To-Be)
각 SObject 타입별로 추출 로직을 전담하는 **전략 패턴(Strategy)** 을 도입합니다.
`IEventExtractor` 인터페이스를 만들고, 맵(Map) 자료구조를 이용해 런타임 라우팅을 구현합니다.

```apex
// 1. 인터페이스 및 전략 클래스 분리
public interface IEventExtractor {
    ResourceInfo extract(SObject event, Map<String, Object> payload);
}

public class ReportExtractor implements IEventExtractor {
    public ResourceInfo extract(SObject event, Map<String, Object> payload) {
        ReportEvent re = (ReportEvent) event;
        // Report 추출 로직...
    }
}

// 2. Publisher 내부 체인 제거 (To-Be)
private static Map<SObjectType, IEventExtractor> extractors = new Map<SObjectType, IEventExtractor>{
    ReportEvent.SObjectType => new ReportExtractor(),
    ApiEvent.SObjectType    => new ApiExtractor()
};

private static ResourceInfo extractResourceInfo(SObject rawEvent, Map<String, Object> payload) {
    IEventExtractor extractor = extractors.get(rawEvent.getSObjectType());
    return (extractor != null) ? extractor.extract(rawEvent, payload) : defaultExtractor.extract(rawEvent, payload);
}
```
**✨ 기대 효과**: 특정 이벤트의 추출 로직을 수정하다가 다른 이벤트의 로직을 망가뜨릴 위험이 사라집니다(단일 책임 원칙 준수). 응집도가 높아져 코드를 읽기가 훨씬 편해집니다.

---

# 🥈 Tier 2 : Structural Debt (구조적 기술 부채 청산)

## 4. 거대 유틸리티 클래스의 책임 분할 (Facade / SRP Pattern)

`SecurityGuard.cls`는 350라인이 넘어가는 거대한 Бог(God) 클래스에 가깝게 모든 기능을 가지고 있습니다. 단일 책임 원칙(SRP) 위배를 해결해야 합니다.

### 🔴 현재 코드의 문제점 (As-Is)
사용자 캐싱, 권한 확인, 쿼리 파싱, 시간 및 데이터 임계치 확인, 심지어 메타데이터 SOQL 캐싱 로직까지 모두 하나의 클래스에 욱여넣어져 있습니다.
특정 검증 로직 하나를 고치기 위해 프레임워크 전반의 코어 유틸리티를 수정해야 하므로 부작용(Side-effect) 발생 확률이 큽니다.

### 🟢 리팩토링 제안 (To-Be)
기능별로 잘게 쪼개진 헬퍼 클래스들을 만들고, 제일 앞단에는 **퍼사드 패턴(Facade)** 을 두어 클라이언트는 기존처럼 편하게 호출하도록 만듭니다.

```apex
// 1. 도메인별 책임 분할 (SRP 준수)
public class SecurityUserHelper { public static Boolean isAdmin(User u) { ... } }
public class SecurityTimeHelper { public static Boolean isOffHours() { ... } }
public class SecurityQueryAnalyzer {
    public static Boolean isPrivilegeEscalation(String query) { ... }
}

// 2. 퍼사드 클래스 (Facade) - 인터셉터들은 이 클래스만 바라봄
public class SecurityGuard {
    public static Boolean isAdmin(User u) { return SecurityUserHelper.isAdmin(u); }
    public static Boolean isOffHours() {
        return SecurityTimeHelper.isOffHours();
    }
    // ...
}
```
**✨ 기대 효과**: 유틸리티의 결합도가 낮아져 유닛 테스트(`SecurityQueryAnalyzerTest` 등) 작성이 훨씬 쉬워지고 코드 라이프사이클 관리가 안정화됩니다.

---

## 5. 메타데이터 조회 최적화 및 중앙 제어 (Registry / Singleton Pattern)

보안 프레임워크 전역에서 Custom Metadata(`SecurityPolicy__mdt`, `SecurityInboundAction__mdt`, `SecurityIntegration__mdt`)를 조회하고 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
`SecurityGuard`, `SecurityInterfaceBridge`, `SecurityActionInboundHandler` 등 각자의 클래스 안에서 하드코딩된 `[SELECT ... FROM ...__mdt]` SOQL 쿼리를 날리고 있습니다.
메타데이터 쿼리는 일반 SOQL Limits에 카운트되지는 않지만, 반복적인 DB I/O는 트랜잭션 지연을 유발합니다. 또한 캐싱 로직(`Map<String, ...__mdt>`)이 클래스별로 파편화되어 있어 로직이 중복됩니다.

### 🟢 리팩토링 제안 (To-Be)
모든 메타데이터 로딩 및 캐싱을 중앙에서 통제하는 **레지스트리(Registry)** 또는 **싱글톤(Singleton)** 패턴의 전담 관리자를 도입합니다.

```apex
// To-Be: 중앙 집중형 메타데이터 레지스트리
public class SecurityMetadataRegistry {
    // 싱글톤 인스턴스
    private static SecurityMetadataRegistry instance;
    
    // 메모리 캐시 저장소
    private Map<String, SecurityPolicy__mdt> policyCache;
    private Map<String, SecurityIntegration__mdt> integrationCache;
    
    public static SecurityMetadataRegistry getInstance() {
        if (instance == null) instance = new SecurityMetadataRegistry();
        return instance;
    }

    // 정책 조회 (최초 1회만 SOQL 조회, 이후 메모리 반환)
    public SecurityPolicy__mdt getPolicy(String policyCode) {
        if (!policyCache.containsKey(policyCode)) {
            // SOQL 쿼리 실행 후 캐시에 밀어넣기...
        }
        return policyCache.get(policyCode);
    }
}

// 클라이언트 사용처 (SecurityGuard, Bridge 등)
SecurityPolicy__mdt policy = SecurityMetadataRegistry.getInstance().getPolicy('NIGHT_MASS_API');
```
**✨ 기대 효과**: 프레임워크 전반에 흩어진 SOQL 쿼리 및 캐싱 로직이 하나로 통합되어 유지보수가 편해지며, 런타임 성능(응답 속도)이 극대화됩니다. 테스트 코드를 작성할 때 이 Registry에 가짜(Mock) 메타데이터를 주입하기도 훨씬 쉬워집니다.

---

## 6. 웹훅 계열 액션의 중복 제거 (Flyweight / Data-Driven Pattern)

현재 `SecurityNotifySlackAction`, `SecurityNotifyTeamsAction`, `SecuritySendToSiemAction` 등 외부 연동 클래승의 코드를 보면 내부 구조가 완전히 똑같습니다.

### 🔴 현재 코드의 문제점 (As-Is)
단지 하드코딩된 액션 타입 파라미터(`'NOTIFY_SLACK'`, `'NOTIFY_TEAMS'`) 하나만 다를 뿐, 수많은 보일러플레이트 클래스(.cls 파일)가 낭비되고 있습니다.

```apex
// SecurityNotifySlackAction.cls
protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
    SecurityInterfaceBridge.callForAction('NOTIFY_SLACK', originalPayloadJson);
}

// SecurityNotifyTeamsAction.cls (이름만 다르고 완벽히 똑같음!)
protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
    SecurityInterfaceBridge.callForAction('NOTIFY_TEAMS', originalPayloadJson);
}
```

### 🟢 리팩토링 제안 (To-Be)
이 껍데기뿐인 10여개의 클래스들을 모두 삭제하고, 생성자 매개변수를 통해 상태를 주입받는 단 하나의 **범용 연동 액션 클래스(`SecurityWebhookAction`)** 로 통폐합합니다.

```apex
// To-Be: 단 하나의 Webhook 전담 Action
public class SecurityWebhookAction extends SecurityBaseAction {
    private String actionPrefix;
    
    // 생성자로 식별자를 주입 (의존성 주입 기법)
    public SecurityWebhookAction(String prefix) {
        this.actionPrefix = prefix;
    }

    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        SecurityInterfaceBridge.callForAction(this.actionPrefix, originalPayloadJson);
    }
}
```

팩토리(또는 메타데이터)에서 생성할 때 `new SecurityWebhookAction('NOTIFY_TEAMS')` 형태로 던져주기만 하면, **Apex 클래스 파일의 개수가 획기적으로 줄어들어(10개 -> 1개) 메타데이터 의존성이 낮아지고 패키지 관리가 편해집니다.**

---

# 🥉 Tier 3 : Future Proofing (확장성 및 미래를 위한 설계)

## 7. 거대 객체 조립 공정의 캡슐화 (Builder Pattern)

`SecurityAlertPublisher.cls`의 `publish()` 메서드를 보면, 맵(Map)을 선언하고, 리소스 정보를 추출하고, 시간 키를 조합하고, JSON을 직렬화한 뒤 최종적으로 `SecurityAlert__e` 객체의 10여 개 필드를 맵핑하는 복잡한 조립 공정을 거칩니다.

### 🔴 현재 코드의 문제점 (As-Is)
이벤트 페이로드에 들어갈 필드가 하나만 추가되어도 `publish()` 함수의 파라미터가 늘어나거나 내부 구현이 지저분해집니다. 가독성이 매우 떨어지며 생성 로직의 캡슐화가 깨져 있습니다.

### 🟢 리팩토링 제안 (To-Be)
이벤트 페이로드와 Platform Event 레코드 생성을 전담하는 **빌더 패턴(Builder Pattern)** 을 도입합니다.

```apex
// To-Be: 빌더 체이닝을 통한 직관적인 객체 생성
SecurityAlert__e alert = new SecurityAlertBuilder()
    .setSource(source)
    .setPolicy(policyCode, severity)
    .setTargetUser(user)
    .extractResourceFrom(rawEvent)
    .build();

emitEvent(alert);
```
**✨ 기대 효과**: 데이터 세팅 로직과 실제 객체 생성 로직이 분리외어 `Publisher` 클래스는 그저 배달(Emit)에만 집중할 수 있게 됩니다. 테스트 클래스에서도 가짜 이벤트를 찍어낼 때 이 빌더를 재사용할 수 있어 극도로 편리해집니다.

---

## 8. 로직 훼손 없는 부가 기능 덧붙이기 (Decorator Pattern)

`SecurityActionExecutor.cls`의 `executeWithLogging()`를 보면 순수하게 조치(Action)를 실행하는 것 외에 시작 로그, 에러 StackTrace 가공, 최종 DB Upsert 등 부가적인 횡단 관심사 로직이 강하게 결합되어 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
추후에 "Callout 실패 시 3번 재시도하는 기능"이나 "Slack 알림에 대해서만 특별한 포맷의 로그를 남기는 기능"을 추가하려면 Executor 엔진의 본문을 열어서 `try-catch` 안에 지저분한 분기문을 계속 넣어야 합니다.

### 🟢 리팩토링 제안 (To-Be)
실제 액션을 감싸서(Wrap) 부가 기능을 덧붙이는 **데코레이터 패턴(Decorator Pattern)** 을 사용합니다.

```apex
// 1. 데코레이터 클래스 디자인
public class LoggingActionDecorator implements ISecurityAction {
    private ISecurityAction innerAction;
    
    public LoggingActionDecorator(ISecurityAction action) {
        this.innerAction = action;
    }
    
    public void execute(String payload) {
        SecuritySoarTrace.log('Start: ' + innerAction);
        try {
            innerAction.execute(payload); // 실제 조치 실행 위임
        } catch (Exception e) {
            saveErrorLog(e);
            throw e;
        }
    }
}

// 2. 팩토리 조립 시 데코레이터 씌우기 (양파 껍질처럼 감싸기)
ISecurityAction coreAction = new SecurityNotifySlackAction();
ISecurityAction wrappedAction = new LoggingActionDecorator(new RetryActionDecorator(coreAction, 3));

// 3. Executor는 껍데기만 실행함 (내부의 로깅, 재시도가 알아서 연쇄 동작)
wrappedAction.execute(payload);
```
**✨ 기대 효과**: 핵심 실행 엔진(`Executor`)은 군더더기 없이 `action.execute()` 한 줄만 남게 되며, 어떤 조치에 어떤 부가기능(로깅, 캐싱, 재시도)을 붙일지 팩토리에서 동적으로 레고 조립하듯 제어할 수 있게 됩니다.

---

## 9. 복잡한 보안 검증 로직의 규격화 (Specification Pattern)

`SecurityValidator.cls`는 LWC나 Apex 파트에서 보안 검증을 수행하기 위해 만들어진 범용 클래스입니다. 하지만 내부를 보면 `if (isAdmin)`, `if (isOffHours)`, `if (isSensitiveObject)` 등 수많은 하드코딩된 조건(Rule)들이 절차지향적으로 나열되어 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
"심야 시간대이면서 민감 오브젝트를 100건 이상 조회하는 스케줄러 계정"과 같은 **복합 조건**이 생겨나면 `SecurityValidator` 내부에 끝도 없는 다중 `if-else` 블록이 생겨나며 유지보수가 불가능해집니다.

### 🟢 리팩토링 제안 (To-Be)
개별적인 검증 규칙을 독립적인 클래스로 쪼개고, 이들을 레고 블록처럼 논리 연산(AND/OR/NOT)으로 조합할 수 있는 **스펙(Specification) 패턴**을 도입합니다.

```apex
// 1. 단일 스펙(규칙) 정의
public class OffHoursSpecification implements ISpecification {
    public Boolean isSatisfiedBy(SecurityContext ctx) {
        return ctx.hour >= 22 || ctx.hour <= 6;
    }
}
public class AdminSpecification implements ISpecification { ... }

// 2. 스펙의 논리적 조합 (And, Or, Not)
ISecurityRule strictRule = new AndSpecification(
    new AdminSpecification().not(), // 관리자가 아닐 때
    new OffHoursSpecification()     // 심야 시간일 때
);

// 3. Validator는 조합된 룰 덩어리만 검사함
if (strictRule.isSatisfiedBy(currentContext)) {
    blockUser();
}
```
**✨ 기대 효과**: 검증 로직들이 완벽히 독립되어 유닛 테스트가 극도로 쉬워지며, 메타데이터 연동을 통해 "어떤 조건들을 조합할지"를 Apex 수정 없이 동적으로 결정할 수 있는 강력한 Rule Engine으로 발전할 수 있습니다.

---

## 10. 인바운드 웹훅의 중앙 집중 제어 (Front Controller / Proxy Pattern)

`SecurityActionInboundHandler.cls`는 팀즈에서 승인 버튼을 눌렀을 때 들어오는 외부 요청을 처리합니다. 현재 URL 파싱, 토큰 검증, JTI(재사용 방지) 검사, 플랫폼 이벤트 DML 로직이 한 곳에 모여 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
향후 Slack, Discord, 혹은 내부 결재 시스템(Approval Process) 연동 핸들러가 추가될 경우, 토큰을 검증하고 서명을 확인하는 동일한 로직을 핸들러마다 복사 붙여넣기(Copy & Paste) 해야 합니다.

### 🟢 리팩토링 제안 (To-Be)
모든 외부 유입을 한 곳에서 가로채서 공통 보안(인증, 서명, JTI)을 먼저 뚫어내는 **프론트 컨트롤러(Front Controller)** 또는 **프록시(Proxy)** 패턴을 구축합니다.

```apex
// To-Be: 모든 인바운드 요청을 앞단에서 방어하는 Proxy/Front Controller
public class InboundSecurityProxy {
    private IInboundAction realHandler;

    public InboundSecurityProxy(IInboundAction handler) {
        this.realHandler = handler;
    }

    public void handleRequest(RestRequest req) {
        // 1. 공통 방어벽 가동 (토큰 만료 검증, 서명 검사, 방화벽)
        SecurityTokenValidator.verify(req);
        
        // 2. 검증 통과 시 실제 담당 핸들러로 라우팅 (Teams, Slack 등)
        realHandler.run(req);
    }
}
```
**✨ 기대 효과**: 개별 핸들러 모듈(Teams 등)은 순수하게 '비즈니스 처리'에만 집중하면 되고, 해킹 시도를 차단하는 중앙 방어벽은 한 곳에서만 엄격하게 관리할 수 있습니다.

---

## 10. 로깅 아키텍처의 유연성 확보 (Observer / Proxy Pattern)

`SecuritySoarTrace.cls`는 현재 프레임워크 전반의 발자취를 추적하기 위해 `System.debug()` 하나만 단순하게 찍어내고 있습니다.

### 🔴 현재 코드의 문제점 (As-Is)
만약 내일 당장 "모든 CRITICAL 등급의 로그는 Datadog, Splunk 등의 외부 시스템으로 Callout 하라"거나 "특정 이력은 Salesforce Custom Object(`Log__c`)에 적재하라"는 요구사항이 떨어지면, 100군데가 넘는 `System.debug()`를 일일이 찾아 고쳐야 합니다.

### 🟢 리팩토링 제안 (To-Be)
로그 이벤트를 발행/구독하는 **옵저버(Observer) 패턴** 또는 **어댑터(Adapter)** 를 결합한 구조로 전환합니다.

```apex
// To-Be: 다중 대상 구독형 Logger 구조 (Observer)
public class SecuritySoarTrace {
    // 로그를 받아먹을 객체들(구독자) 리스트
    private static List<ILogObserver> observers = new List<ILogObserver>{
        new SystemDebugObserver(), 
        new SplunkCalloutObserver() // 추후 플러그인처럼 추가 가능!
    };

    public static void log(String location, Map<String, Object> ctx) {
        LogEvent e = new LogEvent(location, ctx);
        // 모든 구독자에게 로그를 전파
        for (ILogObserver obs : observers) {
            obs.onLogCreated(e);
        }
    }
}
```
**✨ 기대 효과**: 로그 기록 매체(Terminal, Splunk, Platform Event DB 등)가 아무리 늘어나거나 변경되어도, 비즈니스 코드와 메인 유틸리티(`SecuritySoarTrace`)는 단 1줄도 수정될 필요가 없습니다. (OCP 극대화)

---

# 🧬 Tier 4 : Ultimate Architecture (패키징 및 완전한 확장성)

*(본 단락은 17번~19번 아키텍처 진화 문서와의 정합성을 위해 추가되었습니다.)*

## 12. Zero-Code 무코딩 확장성 (Universal Interceptor & Template)
기존 Tier 1(팩토리 리플렉션)이 "Apex 클래스만 새로 짜면 된다" 였다면, 궁극적인 최종 단계는 **"Apex 코드 생성조차 필요 없는 100% 마우스 드래그 앤 드롭 수준의 설정(Zero-Code)"** 입니다.
17번 스펙 문서에서 설계된 **범용 웹훅 템플릿(Generic Webhook Action)**과 **범용 인터셉터(Universal Interceptor)** 를 도입하여 코딩 비용을 제로(0)로 만듭니다.

## 13. 패키징 범위(Scope)와 접근 제어자 캡슐화 (Visibility Control)
AppExchange(ISV) 파트너 환경, 혹은 비공개(Unlisted) Managed Package로 솔루션을 빌드하기 위해서는 내부 로직의 강력한 은닉이 필요합니다.
* 외부에서 플러그인처럼 상속받아 확장해야 하는 Base 클래스나 인터페이스는 **`global`** 로 격상시킵니다.
* 타인에게 노출되면 안 되는 인터셉터나 코어 라우팅 엔진은 철저하게 **`public`** (또는 `@namespaceAccessible` 캡슐화)으로 강등시켜 블랙박스 방어 체계를 갖춥니다. (자세한 내용은 18번 문서 참조)

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
