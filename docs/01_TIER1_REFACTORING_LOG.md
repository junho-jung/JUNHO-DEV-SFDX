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

---

> 💡 **다음 단계 (Next Steps):** Tier 1 작업이 성공적으로 컴파일됨에 따라, 구조적 기술 부채를 완전히 덜어내기 위한 **Tier 2 (퍼사드 분할, 메타데이터 레지스트리, 웹훅 액션 통폐합)** 작업으로 이행할 준비가 완료되었습니다.
