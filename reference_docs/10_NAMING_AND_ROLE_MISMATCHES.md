# 🏷️ 10. 네이밍 미스매치 및 역할 불일치 (Naming and Role Mismatches)

초기 아키텍처 설계와 실제 개발 구현체 간에 발생한 **역할(Role)과 이름(Naming)의 불일치(Mismatch)** 를 객체 유형별로 리스트업한 체크리스트입니다. 

향후 리팩토링 진행 시 이 체크리스트(As-Is / To-Be)를 기반으로 네이밍을 수정(Rename)하여 시스템의 가독성과 유지보수성을 극대화할 수 있습니다. 이미 역할과 이름이 완벽하게 일치하는 객체(예: `SecurityKillSwitch`, `SecurityPrivilegeEscalator`)는 본 리스트에서 제외되었습니다.

---

## 📋 [체크리스트] 리네이밍 타겟 (Renaming Targets)

### 1. 커스텀 메타데이터 (Custom Metadata Types)

| 상태 | As-Is (현재 이름) | 실제 수행 역할 (불일치 사유) | To-Be (변경 제안 이름) |
| :---: | :--- | :--- | :--- |
| [ ] | `SecurityInboundConfig__mdt` | 인바운드 설정뿐만 아니라, **글로벌 아웃바운드 Throttling 제한**과 **프레임워크 Kill Switch** 등 글로벌 코어 설정을 모두 품고 있음. | **`SecurityGlobalConfig__mdt`** |
| [ ] | `SecurityIntegration__mdt` | 실제 외부 연동 인증/설정은 `InterfaceConfig__mdt`에 있음. 해당 객체는 단순히 ActionType을 Async/Sync **큐(Queue)로 라우팅하는 역할**만 수행. | **`SecurityActionRoute__mdt`** |
| [ ] | `InterfaceConfig__mdt` | Interface라는 단어가 너무 포괄적임. 실제로는 **HTTP Callout(REST) 엔드포인트 및 인증(Named Credential)** 전용 설정 객체임. | **`HttpCalloutConfig__mdt`** |

<br/>

### 2. 표준 / 커스텀 오브젝트 (SObjects)

| 상태 | As-Is (현재 이름) | 실제 수행 역할 (불일치 사유) | To-Be (변경 제안 이름) |
| :---: | :--- | :--- | :--- |
| [ ] | `SecurityAuditLog__c` | 단순 단방향 기록(Audit)이 아님. 현재 `AlertCount__c`를 통해 **유저별 위협 누적 임계치를 실시간으로 갱신하는 '상태 레코드'** 역할 수행. (차세대 아키텍처에서는 주축이 됨) | **`SecurityUserState__c`** |
| [ ] | `InterfaceLog__c` | 외부 전송 결과를 기록. Interface라는 모호한 단어보다는 실제 행위인 Callout 결과를 명시하는 것이 아키텍처 직관성에 부합함. | **`HttpCalloutLog__c`** |

<br/>

### 3. Apex 클래스 (Apex Classes)

| 상태 | As-Is (현재 이름) | 실제 수행 역할 (불일치 사유) | To-Be (변경 제안 이름) |
| :---: | :--- | :--- | :--- |
| [ ] | `SecurityGuard.cls` | 단순 수문장이 아니라, 메타데이터 읽기, 캐싱, IP/시간 임계치 계산 등 전반적인 **중앙 정책 평가 엔진**으로 거대하게 동작 중. | **`SecurityPolicyEvaluator.cls`** |
| [ ] | `SecurityValidator.cls` | `SecurityGuard`와 역할이 헷갈림. 실제로는 LWC나 Apex 앞단에서 '우회 가능한 관리자인지' 확인하는 단순 **접근 권한 체커기** 역할을 수행 중. | **`SecurityAccessChecker.cls`** |
| [ ] | `SecurityInterfaceBridge.cls` | Action을 팩토리에서 만든 뒤, 동기/비동기 방식을 결정하여 던져주는 **디스패처(Dispatcher)** 역할. | **`SecurityActionDispatcher.cls`** |
| [ ] | `InterfaceBatch.cls`<br>`InterfaceQueueable.cls`<br>`InterfaceRealTime.cls` | 3개 모두 "Interface"라는 추상적 단어 사용. 내부 구현체는 철저하게 Http Callout 전용 로직(Header, Body 세팅)들로만 구성되어 있음. | **`HttpCalloutBatch.cls`<br>`HttpCalloutQueueable.cls`<br>`HttpCalloutRealTime.cls`** |
| [ ] | `SecurityActionFactory.cls` | 현재는 하드코딩된 `switch` 분기문을 사용하지만, 향후 리플렉션을 통해 동적으로 객체를 조립(Build)하는 **빌더/레지스트리** 역할로 전환 예정. (리팩토링 병행 시점) | **`SecurityActionBuilder.cls`** |

---

## 🎯 활용 방안
1. 본 체크리스트 테이블의 상태 `[ ]` 칸은 향후 VSCode 글로벌 검색 및 변경(Global Search & Replace) 기능 등을 통해 리팩토링을 수행할 때 **작업 진행 현황(Progress) 마킹용**으로 사용할 수 있습니다.
2. 메타데이터와 SObject 이름 변경 시(특히 API Name 변경 시), 연관된 Apex 클래스 내의 모든 SOQL 쿼리와 할당 구문도 동시에 업데이트되어야 함을 주의하십시오.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
