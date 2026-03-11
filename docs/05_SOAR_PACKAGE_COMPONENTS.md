# 📦 05. SOAR 프레임워크 패키징 컴포넌트 전수 레이블링 (Comprehensive Component Labeling)

본 문서는 현재 조직(Org)에 존재하는 **모든 Custom Object, Platform Event, Custom Metadata, 그리고 주요 Apex Class**를 전수 조사하여, 해당 컴포넌트가 **보안(SOAR) 프레임워크 소속인지(O/X)** 와 차후 관리형 **패키지(Managed Package)에 포함시킬지 여부(O/X)** 를 명확히 판별한 레이블링 문서입니다. 

이를 통해 테스트 코드를 짤 대상(패키지 포함 대상)과 무시해도 되는 대상을 완벽하게 분리할 수 있습니다.

---

## 🗄️ 1. Data Model (Custom Objects & Platform Events)

전체 Object 중에서 순수 SOAR 프레임워크의 상태와 로그를 관리하는 오브젝트만 패키징합니다.

| SObject API Name | 오브젝트 유형 | 설명 및 역할 | SOAR (O/X) | Package (O/X) |
| :--- | :---: | :--- | :---: | :---: |
| `SecurityAuditLog__c` | Custom Object | 유저별 위협 발생 카운트 및 누적 상태 (상태 머신 본체) | 🔵 O | 🟢 O |
| `SecurityActionLog__c` | Custom Object | 시스템이 실행한 차단/알림 액션의 결과 및 에러 추적 로그 | 🔵 O | 🟢 O |
| `SecurityInboundTokenUsed__c`| Custom Object | 외부 인바운드 조치 버튼(Teams 등)의 1회성 토큰 재사용 방지 기록 | 🔵 O | 🟢 O |
| `SecurityActionRequest__e` | Platform Event | 대시보드 및 인바운드의 수동 조치 요청용 비동기 버스 | 🔵 O | 🟢 O |
| `SecurityAlert__e` | Platform Event | TxnSecurity 감지 이벤트의 비동기 우회 버스 | 🔵 O | 🟢 O |
| `InterfaceLog__c` | Custom Object | 구형 Interface Callout 프레임워크 결과 로그 | ❌ X | ❌ X |
| `Interface__c` | Custom Object | 구형 Interface 마스터 데이터 | ❌ X | ❌ X |
| `Setting__c` | Custom Object | 앱 전역 하드코딩 설정 정보 | ❌ X | ❌ X |
| `ContactUs__c` | Custom Object | (비즈니스) 고객 문의 데이터 | ❌ X | ❌ X |
| `Department__c` | Custom Object | (비즈니스) 부서 정보 | ❌ X | ❌ X |
| `Employee__c` | Custom Object | (비즈니스) 임직원 정보 | ❌ X | ❌ X |
| `MonthlyEstimation__c` | Custom Object | (비즈니스) 월간 견적 정보 | ❌ X | ❌ X |
| `ProjectMember__c` | Custom Object | (비즈니스) 프로젝트 투입 멤버 | ❌ X | ❌ X |
| `S3Files__c` | Custom Object | (비즈니스) AWS S3 파일 연동 로그 | ❌ X | ❌ X |
| `SalesReport__c` | Custom Object | (비즈니스) 영업 리포트 데이터 | ❌ X | ❌ X |

---

## 🧩 2. Custom Metadata Types (CMDT)

설정 메타데이터 중, 레거시 종속성이 있는 `SecurityIntegration__mdt`는 제외하고, 신규 설계된 통신 규격 정보만 포함합니다.

| Metadata API Name | 기획 의도 및 역할 | SOAR (O/X) | Package (O/X) |
| :--- | :--- | :---: | :---: |
| `SecurityPolicy__mdt` | 위협 감지 시나리오 및 조치(임계치) 조건 마스터 | 🔵 O | 🟢 O |
| `SecurityWebhookConfig__mdt`| 순수 SOAR 전용 외부 웹훅(Slack/Teams) 통신 설정 (Tier 2 신설) | 🔵 O | 🟢 O |
| `SecurityInboundAction__mdt`| 인바운드 버튼 클릭 시 매핑할 Apex Class 리플렉션 네임 | 🔵 O | 🟢 O |
| `SecurityInboundConfig__mdt`| 킬스위치, 토큰 유효시간 등 보안 글로벌 환경 설정 | 🔵 O | 🟢 O |
| `SecurityIntegration__mdt` | 구형 `Interface__c` 체계의 ID 매핑 기록용 레거시 설정 | 🔵 O | ❌ X |
| `InterfaceConfig__mdt` | 사내 공통 외부 HTTP 통신 설정 (SOAR 종속 아님) | ❌ X | ❌ X |
| `TriggerHandlerSetting__mdt`| 트리거 통합 프레임워크의 트리거 활성/비활성 설정 | ❌ X (공통) | ❌ X |
| `TriggerHandler__mdt` | 트리거 통합 프레임워크의 핸들러 연결 매핑 설정 | ❌ X (공통) | ❌ X |

---

## 💻 3. Apex Classes (Core, Legacy, & Business)

클래스는 종류가 방대하므로, **카테고리(Category)** 단위로 그룹화하여 레이블링했습니다.

### 3-1. SOAR 프레임워크 코어 엔진 (Include)
모두 SOAR 프레임워크 구동에 필수적이므로 패키지에 **확실히 포함**됩니다.

| Class Name | 기능 계층 | SOAR (O/X) | Package (O/X) |
| :--- | :--- | :---: | :---: |
| `SecurityBaseInterceptor` 및 `EM_*` | 1차 인터셉터(감지) | 🔵 O | 🟢 O |
| `SecurityGuard`, `Security*Filter`, `*Registry` | 중앙 퍼사드 & 캐싱 유틸 | 🔵 O | 🟢 O |
| `IEventExtractor`, `*Extractor` (Api, Report 등) | 이벤트 JSON 다형성 추출 | 🔵 O | 🟢 O |
| `SecurityAlertHandler`, `*Publisher`, `*PolicyResolver`| 오케스트레이션 및 통제 | 🔵 O | 🟢 O |
| `ISecurityAction`, `SecurityActionFactory`, `*Executor`| 리플렉션 기반 액션 엔진 | 🔵 O | 🟢 O |
| `SecurityBaseAction`, `SecurityBaseWebhookAction` | 액션 베이스(플라이웨이트) | 🔵 O | 🟢 O |
| `SecurityKillSession*`, `SecurityFreeze*` 등 내부조치 | Salesforce 로컬 통제 모듈 | 🔵 O | 🟢 O |
| `SecurityNotifySlack*`, `*Teams*` 등 외부조치 | 외부 웹훅 & SIEM 연동 모듈 | 🔵 O | 🟢 O |
| `SecurityDashboard*`, `*Demo*`, `IF_SecurityAction*` | 외부 접근 및 UI 관문 | 🔵 O | 🟢 O |
| `SecurityActionInboundHandler`, `SecurityInboundToken` | 인바운드 REST 처리기 | 🔵 O | 🟢 O |
| `SecurityTypes`, `SecuritySoarTrace`, `*PrivilegeEscalator`| 전역 유틸(구조체, 로깅, System) | 🔵 O | 🟢 O |

### 3-2. SOAR 레거시 브릿지 (Exclude)
보안 조치 모듈이긴 하지만, 구형 `Interface__c` 프레임워크를 억지로 태우기 위한 과도기 래퍼이므로 패키지에서 **배제**합니다.

| Class Name | 기능 계층 | SOAR (O/X) | Package (O/X) |
| :--- | :--- | :---: | :---: |
| `SecurityInterfaceBridge` | 액션을 Interface 프레임워크로 전달하는 중계기 | 🔵 O (과거) | ❌ X |
| `SecurityNotifyTeamsLegacyAction` | 구형 설정 기반 Teams 레거시 발송기 | 🔵 O (과거) | ❌ X |
| `InterfaceTeamsNotifier` | Interface 패키지에 소속된 구형 공용 알림 유틸 | ❌ X | ❌ X |
| `SecurityIntegrationConfig` | Registry 전 사용된 구형 메타데이터 조회 더미 | 🔵 O (과거) | ❌ X |

### 3-3. 비즈니스 로직 및 외부 프레임워크 (Exclude)
본진 Org의 일반적인 LWC 컨트롤러, 사내 공통 통신망(Interface), 트리거 제어 엔진입니다. SOAR와 무관하므로 테스트 및 패키징 검열 대상에서 **완전히 무시**합니다.

| Class Name | 기능 계층 | SOAR (O/X) | Package (O/X) |
| :--- | :--- | :---: | :---: |
| `InboundRestHandler` | 공통 REST API 처리를 위한 사내 범용 래퍼 | ❌ X (공통) | ❌ X |
| `InterfaceHandler`, `*Batch`, `*Queueable`, `*RealTime` | 대규모 Http Callout 처리를 위한 사내 통신 프레임워크 | ❌ X | ❌ X |
| `TriggerHandler`, `ITrigger` 등 | 공용 Trigger 제어(바이패스) 프레임워크 | ❌ X (공통) | ❌ X |
| `Util*` (`UtilString`, `UtilSchema`, `UtilDate` 등) | 사내 공통 유틸리티 모음 (SOAR 전용 기능 없음) | ❌ X (공통) | ❌ X |
| `*Controller` (`Account*`, `EmailConfig*`, `ContactUs*`) | 특정 LWC 화면에 대응되는 비즈니스 Apex | ❌ X | ❌ X |
| `AuditMailService`, `CaseViewHandlerController` | 이메일 발송 / Case 뷰 LWC 등의 비즈니스 | ❌ X | ❌ X |
| `PMS*`, `Oppty*`, `SalesReport*` 관련 모듈 | 사내 관리(PMS) 및 기회(Opportunity) 비즈니스 모듈 | ❌ X | ❌ X |

---

## 💡 종합 결론

사용자님의 통찰대로 **패키징에 포함되지 않는 찌꺼기 코드(Interface 프레임워크 등)의 단위 테스트까지 억지로 고칠 필요는 전혀 없습니다.**

* 위 리스트에서 **`[Package 🟢 O]`** 라벨이 붙은 Object, Event, Metadata, Class 파일들만 물리적으로 복사하여 떼어내거나(독립 폴더 이동), `package.xml`에 명시하여 독립적인 빌드 큐(Clean Room)를 구성해야 합니다.
* 이후 단위 테스트(Unit Test)를 돌릴 때도, 위 **`3-1. SOAR 프레임워크 코어 엔진`** 표에 속하는 Apex Class에 대한 전용 Test Class(`Security*Test`)들의 커버리지만 75% 이상 확보하면 완벽합니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
