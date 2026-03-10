# 🔄 09. 차세대 아키텍처: 이벤트 소싱과 상태 머신 (Event Sourcing & State Machine)

본 문서는 `08. 면접 대비 질의응답`에서 가장 심도 있는 'Next Step' 아키텍처로 언급되었던 **이벤트 소싱(Event Sourcing) 기반의 상태 머신(State Machine)** 구조에 대한 상세 기획안입니다.

이와 더불어, Salesforce 단일 Org 환경 내에서 **마이크로서비스(Microservices) 형태를 구축한다**는 의미가 전통적인 서버 분산형 MSA와 어떻게 다르고, 어떤 이점을 가지는지 명확히 정의합니다.

---

## 🏗️ 1. Salesforce 내에서의 '마이크로서비스'란?

사용자 질문: *"내가 아는 MSA는 서비스별로 개별 서버(혹은 개별 Salesforce Org)를 구축하는 것인데, 단일 Org 안에서 마이크로서비스 형태를 구축한다는 게 무슨 말이죠?"*

### 💡 1-1. 전통적 MSA vs Salesforce 체제 내의 MSA
일반적인 웹 아키텍처에서 MSA(Microservices Architecture)는 물리적으로 서버(컨테이너)와 DB를 분리하여 장애를 격리하고 개별 확장을 도모합니다. 반면 단일 Salesforce Org는 물리적으로 하나의 거대한 데이터베이스와 서버(Multitenant)를 공유하는 **모놀리식(Monolithic)** 환경입니다. 

그럼에도 불구하고 SOAR 프레임워크에서 "마이크로서비스(MSA) 형태를 추구한다"는 것은 **논리적 디커플링(Logical Decoupling)**과 **이벤트 기반 통신(EDA, Event-Driven Architecture)**을 의미합니다. 이를 업계에서는 **컴포저블 아키텍처(Composable Architecture)** 또는 **모듈러 모놀리스(Modular Monolith)**라고 부릅니다.

### 💡 1-2. 현재 SOAR의 논리적 마이크로서비스 구조
Apex 클래스 간에 `A.execute() -> B.notify() -> C.log()` 형식으로 메서드를 **직접(동기적으로) 호출하지 않습니다.** 

* **기능의 완벽한 분리**: 위협 감지 파트(Detector), 판단 파트(Handler), 발송 파트(Publisher), 연동 파트(InterfaceWebhook)가 각각 독립된 앱처럼 존재합니다.
* **Message Bus (Platform Events)**: 이들은 오직 `SecurityAlert__e` 라는 중앙 메세지 버스(Kafka나 RabbitMQ 역할)를 통해서만 소통합니다.
* **장애 격리 효과 (Fault Tolerance)**: Slack API 서버가 터져서(장애) 알림 발송 모듈이 에러를 뿜어도, Salesforce 내부의 '계정 동결' 모듈은 알림 모듈과 느슨하게 결합(Platform Event 비동기 구독)되어 있으므로 정상적으로 작동하여 보안을 방어해냅니다. **이것이 단일 Org 내에서 MSA의 핵심 철학을 달성한 것입니다.**

---

## 🧬 2. 현재 구조 vs 이벤트 소싱 상태 머신 구조

### 🔴 2-1. 현재 구조 (Linear Pipeline - 선형 파이프라인)
현재 SOAR는 **상태가 없는(Stateless) 단발성 파이프라인**입니다.
1. 사용자가 데이터를 100건 다운로드함 (이벤트 발생)
2. Handler가 `SecurityPolicy__mdt`를 확인 
3. "100건 이상이면 차단 및 Slack 알림" 룰 타격 -> 즉시 Action 실행

* **한계점 (시간과 문맥의 부재)**: 이 시스템은 "어제 의심스러운 활동을 3번이나 한 유저"와 "입사 후 5년 동안 아무 문제 없던 유저"를 똑같이 100건이라는 단일 잣대로만 평가합니다. 시간의 흐름(Context)을 기억하지 못하기 때문입니다.

### 🟢 2-2. 차세대 구조 제안 (Event Sourcing + State Machine)
상태 머신 구조는 사용자의 **현재 보안 상태(State)**를 기록하고, 수많은 파편화된 **이벤트(Event)**들이 쌓여서(Sourcing) 그 상태를 진화시키는 방식입니다.

#### 🔄 이벤트 소싱 (Event Sourcing) 연동
데이터가 변경될 때 최종 결과값(UPDATE)만 저장하는 것이 아니라, **그렇게 되기까지의 모든 이력(이벤트 스트림) 자체를 영구 저장**하는 기법입니다.
* 사용자가 로그인함 (이벤트 삽입)
* 사용자가 실패함 (이벤트 삽입)
* 사용자가 심야에 다운로드함 (이벤트 삽입)
* **어떻게 달라지나?**: 시스템은 이 이벤트 로그(`Security_Event_Stream__c`)를 쭉 읽어 들여서 현재 이 사용자가 해킹당했을 확률을 계산합니다. (과거로 돌아가 특정 시점의 보안 상태를 완벽히 재현(Replay)할 수 있습니다.)

#### 🤖 상태 머신 (State Machine) 전이 로직
단일 사용자의 보안 척도를 여러 개의 **상태(Status)**로 정의합니다.
* `NORMAL` (정상) -> `WATCHING` (주시) -> `SUSPICIOUS` (의심) -> `RESTRICTED` (권한 축소) -> `LOCKED` (격리)

* **어떻게 달라지나?**: 동일한 "심야 데이터 다운로드(Event)"가 발생해도, 유저의 현재 상태에 따라 시스템의 반응(Action)이 완전히 달라집니다.
  1. `NORMAL` 상태 유저가 심야 다운로드 -> 상태를 `WATCHING`으로 변경 (아무 조치 안 함, 기록만)
  2. `WATCHING` 상태 유저가 연속 다운로드 -> 상태를 `SUSPICIOUS`로 격상시키고 팀장 관리자에게 승인 요청(Inbound Webhook) 알림
  3. 팀장이 10분 내 응답 없음(Timeout Event 발생) -> 상태를 `RESTRICTED`로 바꾸고 대시보드 접근 권한 박탈

---

## 🛠️ 3. 도입 시 구체적으로 필요한 설계 변화

이 구조를 도입하려면 Apex 기반 시스템 설계가 근본적으로 변해야 합니다.

| 컴포넌트 | 현재 방식 (As-Is) | 차세대 방식 (To-Be) |
| :--- | :--- | :--- |
| **Data Model** | `SecurityAlert__c` (단일 알럿 위주) | `Security_State__c` (유저별 현재 상태 보유)<br>`Security_Event_Stream__e/c` (모든 행위 로그) |
| **평가 엔진** | 1개 이벤트 -> N개 Policy 단순 비교 | (Old State + New Event) -> **상태 전이 공식(Transition Matrix)** 평가 -> New State 반환 |
| **조치 타이밍** | 이벤트 감지 즉시 실행 | **상태(State)가 변경되는 순간**에만 조치(Side Effect) 실행 |
| **Context** | 직전 트랜잭션의 임계치만 봄 | 과거 이벤트 스트림을 취합(Reduce)하여 Anomaly(이상 행동) 패턴 인지 가능 |

### 🚀 도입 시 얻게 되는 궁극의 장점 (Why do this?)

1. **오탐지(False Positive)의 획기적 감소**: 단편적인 룰(Rule) 기반 차단에서 발생하는 선의의 피해자를 줄일 수 있습니다. (문맥 기반 판단)
2. **시나리오 기반의 지능형 대응**: "로그인 실패 3회 후 10분 뒤 대량 다운로드" 등 복합적이고 시간차를 둔 다단계 해킹 시나리오(APT 공격 등)를 감지하고 잡아낼 수 있습니다.
3. **AI/ML 연동의 초석**: 이벤트 소싱으로 쌓인(Sourcing) 방대한 사용자 미세 행동 로그는 머신러닝의 완벽한 학습 데이터가 됩니다. 향후 Einstein AI와 결합하여 "이상 행동 감지 가중치"를 자동으로 산출할 수 있게 됩니다.

---

## 🏗️ 4. 기존 아키텍처(TSP & AuditLog)를 활용한 현실적인 확장 방안

완전히 새로운 인프라를 바닥부터 짤 필요 없이, **현재 Security SOAR가 보유한 자원만으로도 State Machine 구조로의 점진적 전환이 완벽히 가능합니다.** 오히려 질문하신 방식이 실무적으로 가장 올바른 접근(Evolutionary Architecture)입니다.

### 💡 4-1. 현재 시스템과의 매핑 (완벽한 아키텍처 호환성)
1. **Event Sourcing (과거 행위와 스트림)**: 
   - 굳이 우리가 따로 이벤트를 수집할 필요가 없습니다. Salesforce의 **TSP(Transaction Security Policy)와 Event Monitoring 자체가 이미 완벽한 'Event Stream' 역할**을 하고 있습니다.
   - 유저의 모든 활동은 Salesforce 코어에 로깅되며, 임계점을 넘은 행위는 `SecurityAlert__e`라는 플랫폼 이벤트 형태로 파이프라인에 흘러들어옵니다. 이것이 곧 Sourcing 대상 이벤트입니다.
2. **State Entity (상태 보관자)**: 
   - 현재 누적 알럿 카운트(`AlertCount__c`) 등을 기록하기 위해 만들어둔 **`SecurityAuditLog__c` 오브젝트를 유저별 '상태 머신(State Machine)' 본체로 격상**시킵니다.

### 💡 4-2. 확장을 위한 구체적인 액션 플랜 (How to extend)

* **Step 1: 상태(State) 컬럼 추가**
  - `SecurityAuditLog__c` 에 `Current_State__c` (Picklist: Normal, Watching, Suspicious, Restricted) 필드를 추가합니다. 기존 `AlertCount__c`는 단순 카운트가 아닌 상태 전이를 위한 '가중치(Score)' 개념으로 흡수됩니다.
* **Step 2: 상태 전이 엔진 (Transition Engine) 도입**
  - 현재 `SecurityAlertHandler`는 `if (alertCount >= threshold)` 처럼 단순 비교 후 즉각 조치(Action)를 취합니다.
  - 이를 개조하여, 이벤트를 받으면 **DB(`SecurityAuditLog__c`)에서 해당 유저의 과거 `Current_State__c`를 꺼내 읽습니다.** 과거 상태와 현재 유입된 이벤트(TSP)를 조합해 다음 상태(Next State)를 계산합니다.
* **Step 3: 트리거 리팩토링 (Action on State Change)**
  - 이벤트가 발생할 때마다 알림을 보내는 것이 아니라, **`SecurityAuditLog__c` 레코드의 `Current_State__c` 필드값이 하위에서 상위 등급으로 변경(Update)되는 순간**에만 알림 발송이나 계정 동결 액션을 트리거하도록 변경합니다.

**✅ 결론**: 
질문하신 내용이 정확히 맞습니다. **현재의 TSP 모니터링 이벤트 체계와 `SecurityAuditLog__c` 구조는 State Machine 아키텍처로 진화하기 위한 완벽한 마중물(Foundation)입니다.** 코어를 통째로 버리는 것이 아니라, AuditLog를 상태 머신 본체로 취급하고 Handler 로직에 '상태 전이 공식'만 덮어씌움으로써 부드럽고 강력하게 확장이 가능합니다.

---

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
