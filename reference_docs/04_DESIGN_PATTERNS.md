# 🎨 04. 디자인 패턴 파트 (Design Patterns)

Security SOAR 프레임워크는 유지보수성과 확장성을 극대화하기 위해 객체지향 프로그래밍(OOP)의 핵심 원칙인 SOLID와 여러 소프트웨어 디자인 패턴(Design Patterns)을 융합하여 설계되었습니다.

본 문서는 `EM_` 및 `Security*` 접두사를 가진 핵심 클래스 내부에서 어떤 설계 패턴이 어떻게 응용되었는지 코어 레벨로 딥다이브(Deep-dive)합니다.

---

## 1. 팩토리 패턴 (Factory Method Pattern)

동적으로 객체 생성을 처리하여 클라이언트(호출자) 코드와 구체적인 클래스 결합도를 낮추는 패턴입니다.

### 적용 컴포넌트
* **`SecurityActionFactory.cls`**

### 딥다이브 (Deep-dive)
SOAR 시스템은 수많은 액션(세션 킬, 유저 동결, 슬랙 알림 등)을 가집니다. 이를 `if-else` 구조로 생성하면 새로운 액션이 추가될 때마다 핸들러 코드가 수정되어야 합니다 (OCP 위배).
`SecurityActionFactory`는 정책 식별자 문자열(`String actionType`)을 받아, 런타임에 그에 맞는 `ISecurityAction` 인터페이스 구현체를 동적으로 반환합니다.

```apex
// 클라이언트(Handler)의 호출부: 구체적인 Action 클래스가 무엇인지 모름
List<ISecurityAction> actions = SecurityActionFactory.create('KILL_SESSION,NOTIFY_SLACK');

for (ISecurityAction act : actions) {
    SecurityActionExecutor.executeWithLogging(act, payload, false);
}
```

이 패턴 덕분에, 향후 "팀즈 알림" 이라는 새로운 조치가 필요할 때 핸들러 로직은 1줄도 수정하지 않고 새로운 `SecurityNotifyTeamsAction`만 추가하면 됩니다.

---

## 2. 템플릿 메서드 패턴 (Template Method Pattern)

부모 클래스에서 알고리즘의 뼈대(흐름)를 정의하고, 자식 클래스에서 일부 단계(세부 구현)를 오버라이드 하도록 하는 패턴입니다.

### 적용 컴포넌트
* **`SecurityBaseAction.cls`** (부모)
* 상속받는 모든 구체적 Action 클래스들 (자식: `SecurityKillSessionAction`, `SecurityFreezeUserAction` 등)

### 딥다이브 (Deep-dive)
모든 보안 액션은 기본적으로 1) 페이로드 파싱, 2) 대상 유저 추출, 3) 런타임 제약 확인, 4) 실제 액션 수행, 5) 에러 핸들링 이라는 공통된 흐름을 가집니다. 부모 클래스인 `SecurityBaseAction`이 `public void execute(String payload)`에 이 큰 뼈대를 박아두고, 구체적 구현체는 **`protected abstract void doExecute(...)`** 만 구현합니다.

```apex
// SecurityBaseAction.cls (부모의 템플릿)
public void execute(String payloadJson) {
    try {
        Map<String,Object> payload = (Map<String,Object>) JSON.deserializeUntyped(payloadJson);
        String targetUserId = (String)payload.get('userId');
        
        // 자식 클래스가 구현한 구체적인 비즈니스 로직 호출
        doExecute(payload, targetUserId, payloadJson); 
        
    } catch (Exception e) {
        throw new SecurityException('Action failed: ' + e.getMessage());
    }
}
```

이를 통해, 예외 처리나 로깅 같은 보일러플레이트 코드를 수십 개의 자식 액션 클래스에 중복으로 작성하지 않아 코드가 획기적으로 깔끔해집니다.

---

## 3. 전략 패턴 (Strategy Pattern)

실행 중에 알고리즘(전략)을 교체할 수 있게 하는 패턴입니다. Salesforce의 Transaction Security는 이 구조를 네이티브로 요구합니다.

### 적용 컴포넌트
* **`TxnSecurity.EventCondition`** (Interface)
* **`SecurityBaseInterceptor.cls`** 및 `EM_***Interceptor` 구현체들

### 딥다이브 (Deep-dive)
Salesforce Transaction Security 정책은 무조건 `TxnSecurity.EventCondition` 인터페이스의 `evaluate(SObject)` 메소드를 구현해야만 동작합니다. 시스템 내부에서는 "비정상 엑스포트 검사 전략", "심야 API 검사 전략" 등 다수의 전략 계층이 존재합니다.
`SecurityBaseInterceptor`가 이 인터페이스를 한 번 받아주고, 하위 서브 클래스(`EM_SecurityBlockInterceptor` 등)가 각자의 전략에 맞춰 `doEvaluate()`라는 전략 알고리즘을 수행하도록 구성되어 있습니다. 향후 새로운 탐지 로직이 필요하면 기존 코드를 건드리지 않고 새로운 Interceptor 전략 클래스 하나만 끼워 넣으면 됩니다.

---

## 4. 인터셉터 패턴 (Interceptor Pattern)

요청이나 이벤트가 최종 목적지에 도달하기 전에 중간에 가로채서(Intercept) 부가 작업이나 필터링을 수행하는 패턴입니다.

### 적용 컴포넌트
* 프레임워크 전반의 **Detection Layer (`EM_***`)**

### 딥다이브 (Deep-dive)
사용자가 `Report`를 엑스포트 하거나 쿼리를 날렸을 때, Salesforce 커널이 이 트랜잭션을 처리하기 직전에 우리가 만든 `SecurityBaseInterceptor`가 끼어듭니다.
이 패턴은 비즈니스 핵심 로직(리포트 렌더링)과 횡단 관심사(접근 감시, 보안 체크)를 완벽하게 분리하는 효과가 있습니다. 사용자는 자신이 뒷단에서 섀도우 모니터링(`EM_SecurityMonitorInterceptor`)을 당하고 있는지, 혹은 MFA(`EM_SecurityMFAInterceptor`) 평가를 받고 있는지 전혀 눈치채지 못합니다.

---

## 5. 옵저버/발행-구독 패턴 (Pub/Sub Pattern)

객체 간의 강한 결합을 풀기 위해, 한 곳에서 이벤트를 '발행(Publish)' 하면, 관심 있는 다른 쪽에서 이를 '구독(Subscribe)' 하여 독립적으로 처리하는 패턴입니다.

### 적용 컴포넌트
* **`SecurityAlertPublisher.cls`** (발행)
* **`SecurityAlert__e`** (이벤트 버스)
* **`SecurityAlertHandler.processAlerts()`** (구독/소비)

### 딥다이브 (Deep-dive)
인터셉터 영역(트랜잭션 내부)에서는 DML 트랜잭션 제한과 Http Callout이 불가능하다는 플랫폼의 치명적인 한계가 있습니다. 이를 돌파하기 위해 옵저버 패턴이 쓰였습니다.
1. 인터셉터는 차단을 선언함과 동시에 조용히 `SecurityAlert__e` 이벤트만 던지고 사라집니다. (Publish)
2. 트랜잭션 구속에서 완전히 풀려난 별도 스레드에서 Platform Event Trigger가 이를 낚아챕니다. (Subscribe)
이 구조 덕택에, 사용자 응답 속도를 저해하지 않으면서도 뒷단에서 무거운 비동기 프로세스(Callout, 슬랙 전송 등)를 마음껏 수행할 수 있습니다.

---

## 6. 싱글톤 패턴 및 메타데이터 의존 지연 (Singleton Pattern & Lazy Evaluation)

객체의 인스턴스가 오직 하나만 생성되도록 보장하고, 설정 값을 필요할 때 단 한 번만 로드하여 캐싱하는 패턴입니다.

### 적용 컴포넌트
* **`SecurityKillSwitch.cls`**
* **`SecurityInboundConfig__mdt`** 쿼리 관련 캐싱 유틸리티

### 딥다이브 (Deep-dive)
SOAR 시스템은 초당 수십 건 이상의 트랜잭션에서 반복 호출될 수 있습니다. 매번 DB에서 Limit 등을 검사하는 SOQL을 치면 곧바로 CPU/SOQL Limit 에러를 발생시킬 수 있습니다.
따라서, 프레임워크의 설정(Limits, Inbound Secret Key)이나 Kill Switch 상태는 첫 접근 시점에만 SOQL 쿼리로 조회하여 `static` 변수에 올려놓고(Lazy Evaluation & Singleton), 이후 후속 트랜잭션에서는 메모리에 캐싱된 데이터만 즉각 리턴합니다. 이는 프레임워크의 퍼포먼스를 유지하는 가장 핵심적인 기법입니다.

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
