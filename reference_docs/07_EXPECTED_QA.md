# ❓ 07. 예상 Q&A (Expected Questions & Answers)

본 문서는 Security SOAR 프레임워크를 도입, 운영, 혹은 커스터마이징하려는 관리자와 개발자들이 흔히 가질 수 있는 의문점들을 **기획(Functional)** 과 **기술(Technical)** 두 가지 측면으로 나누어 상세히 설명합니다.

---

## 🎯 1. 기획/운영 측면 (Functional & Business Q&A)

### Q1. "SOAR 프레임워크를 도입하면 우리 회사에 어떤 비즈니스적 이점이 있나요?"
**A.** 가장 큰 이점은 **'보안 골든타임 확보'**와 **'관리 리소스 절감'**입니다.
기존에는 해킹이나 중요 데이터 외부 유출 시도가 발생하면, 보안 담당자가 다음날 출근하여 리포트를 보고 수동으로 계정을 정지하는 등 대처가 늦었습니다. SOAR를 도입하면 위협 발생 후 **수 초 이내에 시스템이 스스로 판단하여 계정을 차단**하고 Teams/Slack으로 알림을 보냅니다. 24시간 365일 무인 일선 보안 요원이 생기는 것과 같습니다.

### Q2. "모든 보안 위협에 대해 무조건 계정이 잠기거나 차단되나요? 임원진에게는 예외를 둘 수 있나요?"
**A.** 무조건 차단되지 않습니다. SOAR는 **정책(Policy)과 임계치(Threshold)에 기반한 점진적 대응**을 원칙으로 합니다.
예를 들어 데이터를 10건 다운받으면 '경고 알림'만 보내고, 100건을 넘기면 '계정 동결'을 수행하도록 메타데이터(`SecurityPolicy__mdt`)에서 설정할 수 있습니다.
또한 `SecurityGuard`의 예외 처리 로직을 통해 특정 프로필(예: System Administrator)이나 VIP 그룹, 혹은 화이트리스트 IP 대역에 대해서는 강제 조치를 우회하도록 유연하게 설정할 수 있습니다.

### Q3. "Slack이나 Teams 로 알림이 온다는데, 알림 창에서 바로 조치를 취할 수 있나요?"
**A.** 네, 가능합니다. 이를 **대화형(Interactive) 보안 대응**이라고 부릅니다.
SOAR는 외부 웹훅(Inbound Webhook) 연동을 기본 지원합니다. 알림 메세지 내에 `[계정 즉시 잠금]`, `[세션 강제 종료]`, `[오인 경보 처리]` 등의 버튼을 배치할 수 있으며, 이 버튼을 누르면 SOAR의 `SecurityActionInboundHandler`가 요청을 검증(토큰 및 서명)한 뒤 즉각적으로 Salesforce 내부에서 해당 조치를 대행하여 실행합니다.

### Q4. "새로운 보안 규칙 규정이 생겼습니다. 코드를 계속 고쳐야 하나요?"
**A.** 아닙니다. 이 프레임워크는 철저하게 **데이터 주도(Data-Driven)**로 설계되었습니다.
새로운 정책(예: "심야 시간대 로그인 시도")이 필요하다면 Apex 코드를 수정할 필요 없이 관리자 화면에서 `SecurityPolicy__mdt` 레코드만 하나 생성하고 임계치와 액션(예: `NOTIFY_TEAMS`)을 매핑해주면 즉시 반영됩니다.

---

## 💻 2. 기술/개발 측면 (Technical & Architecture Q&A)

### Q1. "보안 이벤트가 동시에 10,000건이 밀려들어오면 트랜잭션 제한(Limits)이나 데드락에 걸리지 않나요?"
**A.** 걸리지 않도록 방어 로직이 겹겹이 설계되어 있습니다.
1. **서킷 브레이커 (Throttling)**: `SecurityActionThrottle` 클래스가 동일한 타겟에 대해 분당 N회 이상의 액션이 트리거되는 것을 차단합니다. 폭주 시나리오를 원천 봉쇄합니다.
2. **Bulk 비동기 큐 (Async Queueing)**: 즉시 실행이 불가능하거나 Callout Limit을 넘어서는 작업들은 `InterfaceQueueable` 혹은 `InterfaceBatch`를 통해 청크(Chunk) 단위로 쪼개어 스케줄러로 안전하게 밀어 넣습니다. 
3. **Platform Events의 디커플링**: 트랜잭션 보안 트리거 안에서 직접 DB DML이나 Callout을 하지 않고, `SecurityAlert__e` 라는 독립적인 플랫폼 이벤트를 던지는 것으로 트랜잭션을 끝내기 때문에 본 트랜잭션에 영향을 주지 않습니다.

### Q2. "사내 표준 메신저가 Slack이 아니라 자체 구축 메신저입니다. 새 알림 채널을 연동하려면 어떻게 해야 하죠?"
**A.** 시스템의 코어 로직은 단 한 줄도 건드릴 필요가 없습니다. (개방-폐쇄 원칙)
1. `SecurityBaseAction`을 상속받는 `SecurityNotifyCustomAction.cls`를 딱 하나 만듭니다.
2. `SecurityIntegration__mdt` 와 `InterfaceConfig__mdt` 에 해당 채널의 엔드포인트와 인증(Named Credential) 방식을 세팅합니다.
3. 팩토리 메타데이터(`SecurityActionMapping__mdt` 등)에 코드를 매핑하면 끝납니다. SOAR 엔진은 나머지 정책 계산부터 로깅, 에러 처리까지 알아서 조립해 줍니다.

### Q3. "프레임워크가 실행은 정상적으로 되는데, 작동 히스토리나 디버깅은 어떻게 하나요?"
**A.** 두 가지 트랙으로 로깅이 진행됩니다.
1. **비즈니스 감사 로그**: `SecurityAuditLog__c`와 `SecurityActionLog__c` 커스텀 오브젝트에 위협 감지 내역과 조치 결과(성공/실패)가 영구적으로 보존됩니다. 이 데이터를 이용해 Salesforce Dashboard로 보안 관제 뷰를 만들 수 있습니다.
2. **시스템 트레이스 로그**: `SecuritySoarTrace.cls`를 통해 프레임워크의 모든 실행 흐름(정책 평가 -> 액션 생성 -> 배포)이 마이크로 단위로 추적됩니다. 추후 리팩토링 계획(05 문서)에 따라 이 트레이스 로그는 Splunk/Datadog 등으로 곧바로 쏠 수 있는 확장 구조를 가집니다.

### Q4. "인바운드 웹훅(메신저 승인 버튼 등) 처리 시 외부에서 악의적으로 URL을 계속 호출하면(Replay Attack) 뚫리는 것 아닌가요?"
**A.** 인바운드 방어벽인 `SecurityTokenValidator`와 토큰 체계가 방어합니다.
Inbound URL에는 JTI(JWT Request ID) 또는 일회성 난수 토큰이 포함되며, 한 번 사용된 토큰은 즉시 만료 처리되어 재사용(Replay) 공격을 무력화합니다. 또한 전송 구간은 모두 HTTPS 위에서 Named Credential 기반의 서명 검증을 거치기 때문에 위변조가 불가능합니다.

### Q5. "향후 도입될 수 있는 가장 큰 리팩토링 변화(Technical Debt 해결)는 무엇인가요?"
**A.** 가장 시급한 해결 과제는 크게 2가지입니다. (자세한 내용은 `05_REFACTORING_OPPORTUNITIES.md` 참고)
1. **리플렉션(Reflection) 도입**: `SecurityActionFactory`의 하드코딩된 거대 `switch` 문을 리플렉션 API(`Type.forName()`)로 교체하여 궁극적인 OCP를 달성하는 것입니다.
2. **옵저버(Observer) 및 전략(Strategy) 패턴**: 각 기능을 인터페이스화 하고 책임 연쇄(Chain of Responsibility) 및 데코레이터 패턴을 씌워, 특정 모듈의 기능이 다른 모듈에 전혀 영향을 주지 않도록 결합도를 극단적으로 낮출 예정입니다.

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
