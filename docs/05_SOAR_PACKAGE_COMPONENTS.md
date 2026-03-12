# 📦 05. SOAR 프레임워크 패키징 컴포넌트 전수 레이블링 (Comprehensive Component Labeling)

본 문서는 현재 조직(Org)에 존재하는 **모든 Custom Object, Platform Event, Custom Metadata, Apex Class**를 전수 조사하여 아래 4가지 레이블을 부여한 종합 인벤토리입니다.

| 레이블 | 의미 |
| :---: | :--- |
| **SOAR** | 보안(SOAR) 프레임워크 소속 여부 |
| **Package** | 관리형 패키지(Managed Package)에 포함할지 여부 |
| **💡 Rename To-Be** | 역할과 이름이 불일치하거나 더 나은 명칭이 있을 때의 리네이밍 권고안 (최대 3개) |

> [!TIP]
> 리네이밍 추천이 **`-`** 인 항목은 현재 이름이 역할을 정확히 반영하고 있어 변경 불필요(✨정상)합니다.

---

## 🗄️ 1. Data Model (Custom Objects & Platform Events)

| SObject API Name | 유형 | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :---: | :--- | :---: | :---: | :--- |
| `SecurityAuditLog__c` | Object | 유저별 위협 발생 카운트 및 누적 상태 (상태 머신 본체) | 🔵 | 🟢 | `SecurityUserState__c` |
| `SecurityActionLog__c` | Object | 실행된 차단/알림 액션의 결과 및 에러 추적 로그 | 🔵 | 🟢 | - |
| `SecurityInboundTokenUsed__c` | Object | 외부 인바운드 조치 버튼의 1회성 토큰 재사용 방지 기록 | 🔵 | 🟢 | - |
| `SecurityActionRequest__e` | Event | 대시보드/인바운드의 수동 조치 요청용 비동기 버스 | 🔵 | 🟢 | - |
| `SecurityAlert__e` | Event | TxnSecurity 감지 이벤트의 비동기 우회 버스 | 🔵 | 🟢 | - |
| `InterfaceLog__c` | Object | 구형 Interface Callout 결과 로그 | ❌ | ❌ | - |
| `Interface__c` | Object | 구형 Interface 마스터 데이터 | ❌ | ❌ | - |
| `Setting__c` | Object | 앱 전역 하드코딩 설정 정보 | ❌ | ❌ | - |
| `ContactUs__c` | Object | (비즈니스) 고객 문의 데이터 | ❌ | ❌ | - |
| `Department__c` | Object | (비즈니스) 부서 정보 | ❌ | ❌ | - |
| `Employee__c` | Object | (비즈니스) 임직원 정보 | ❌ | ❌ | - |
| `MonthlyEstimation__c` | Object | (비즈니스) 월간 견적 정보 | ❌ | ❌ | - |
| `ProjectMember__c` | Object | (비즈니스) 프로젝트 투입 멤버 | ❌ | ❌ | - |
| `S3Files__c` | Object | (비즈니스) AWS S3 파일 연동 로그 | ❌ | ❌ | - |
| `SalesReport__c` | Object | (비즈니스) 영업 리포트 데이터 | ❌ | ❌ | - |

---

## 🧩 2. Custom Metadata Types (CMDT)

| Metadata API Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityPolicy__mdt` | 위협 감지 시나리오 및 조치(임계치) 조건 마스터 | 🔵 | 🟢 | - |
| `SecurityWebhookConfig__mdt` | 순수 SOAR 전용 외부 웹훅 통신 설정 (Tier 2 신설) | 🔵 | 🟢 | - |
| `SecurityInboundAction__mdt` | 인바운드 버튼 클릭 시 매핑할 Apex Class 리플렉션 네임 | 🔵 | 🟢 | - |
| `SecurityInboundConfig__mdt` | 킬스위치, 토큰 유효시간 등 보안 글로벌 환경 설정 | 🔵 | 🟢 | `SecurityGlobalConfig__mdt` |
| `SecurityIntegration__mdt` | 구형 `Interface__c` 체계의 ID 매핑용 레거시 설정 | 🔵 | ❌ | `SecurityActionRoute__mdt` |
| `InterfaceConfig__mdt` | 사내 공통 외부 HTTP 통신 설정 (SOAR 종속 아님) | ❌ | ❌ | - |
| `TriggerHandlerSetting__mdt` | 트리거 통합 프레임워크의 활성/비활성 설정 | ❌ | ❌ | - |
| `TriggerHandler__mdt` | 트리거 통합 프레임워크의 핸들러 연결 매핑 | ❌ | ❌ | - |

---

## 💻 3. Apex Classes

### 3-1. 🛡️ 이벤트 감지 계층 (Event Interception)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityBaseInterceptor` | 모든 인터셉터의 부모 클래스, 공통 예외 처리 | 🔵 | 🟢 | - |
| `EM_SecurityBlockInterceptor` | 데이터 유출 등 심각한 위협을 즉시 차단하는 인터셉터 | 🔵 | 🟢 | - |
| `EM_SecurityMFAInterceptor` | 고위험 작업 시 MFA를 요구하는 인터셉터 | 🔵 | 🟢 | - |
| `EM_SecurityMonitorInterceptor` | 차단 없이 관제/로깅 전용 감시 인터셉터 | 🔵 | 🟢 | - |

### 3-2. 🏛️ 퍼사드 및 정책 평가 계층 (Facade & Policy Evaluation)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityGuard` | 이벤트 유형별 위험도를 분석하는 중앙 퍼사드 (God Class) | 🔵 | 🟢 |  `SecurityPolicyEvaluator`  `SecurityThreatAnalyzer`  `SecurityEventAssessor` |
| `SecurityMetadataRegistry` | `SecurityPolicy__mdt` 등 메타데이터 1회 조회/캐싱 (Singleton) | 🔵 | 🟢 | - |
| `SecurityKillSwitch` | Emergency 비상 정지 스위치 유틸 | 🔵 | 🟢 | - |
| `SecurityPrivilegeEscalator` | System 모드(Without Sharing) 강제 실행 헬퍼 | 🔵 | 🟢 | - |
| `SecurityValidator` | LWC/API 접근 권한 및 관리자 예외 체크 유틸 | 🔵 | 🟢 |  `SecurityAccessChecker`  `SecurityPermissionValidator` |
| `SecurityFilterChain` | 검증기들을 체인으로 묶어 관리하는 기능 | 🔵 | 🟢 | - |
| `ISecurityFilter` | 필터 체인에 들어가는 개별 필터의 인터페이스 | 🔵 | 🟢 | - |
| `SecurityThrottleFilter` | 알람 중복 폭주 방지 스로틀링 필터 | 🔵 | 🟢 | - |
| `SecurityPolicyResolver` | 위협 카운트로부터 적합한 대응 Action을 반환 | 🔵 | 🟢 | - |
| `SecurityActionThrottle` | 연속 발생 시 서킷 브레이커(1시간 1번 등) | 🔵 | 🟢 | - |
| `SecurityTypes` | 프레임워크 전역 Type/Enum/상수 정의 클래스 | 🔵 | 🟢 | - |

### 3-3. 🧩 이벤트 추출 계층 (Extractor Strategy)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `IEventExtractor` | SObject 추출 로직 표준 인터페이스 (Strategy) | 🔵 | 🟢 | - |
| `DefaultEventExtractor` | 기본 JSON 직렬화 추출기 | 🔵 | 🟢 | - |
| `ApiEventExtractor` | `ApiEvent` 전용 페이로드 추출기 | 🔵 | 🟢 | - |
| `ReportEventExtractor` | `ReportEvent` 전용 페이로드 추출기 | 🔵 | 🟢 | - |
| `LoginEventExtractor` | `LoginEvent` 전용 페이로드 추출기 | 🔵 | 🟢 | - |

### 3-4. 🚀 오케스트레이션 계층 (Orchestration)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityAlertPublisher` | `SecurityAlert__e` 이벤트를 비동기 버스에 발행 | 🔵 | 🟢 | - |
| `SecurityAlert_tr` | `SecurityAlert__e` 트리거 핸들러 (이벤트 구독) | 🔵 | 🟢 | - |
| `SecurityAlertHandler` | 이벤트 수신 후 정책 평가 및 액션 오케스트레이션 핸들러 | 🔵 | 🟢 | - |
| `SecurityAlertFallbackJob` | 이벤트 유실 시 재처리(Fallback) 배치 Job | 🔵 | 🟢 | - |

### 3-5. ⚙️ 액션 팩토리 및 실행 엔진 (Execution Engine)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `ISecurityAction` | 모든 보안 액션의 `execute()` 인터페이스 | 🔵 | 🟢 | - |
| `SecurityActionFactory` | 리플렉션(Type.forName)으로 액션 인스턴스 동적 로딩 | 🔵 | 🟢 | - |
| `SecurityActionExecutor` | 액션들을 동기/비동기(Queueable)로 배분 및 수행 | 🔵 | 🟢 | - |
| `SecurityBaseAction` | 페이로드 파싱 및 템플릿 메서드 제공 (Abstract) | 🔵 | 🟢 | - |

### 3-6. ⚔️ 내부 환경 통제 액션 (Internal Actions)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityKillSessionAction` | 유저의 현재 세션(`AuthSession`)을 강제 파기 | 🔵 | 🟢 | - |
| `SecurityFreezeUserAction` | 유저 `IsFrozen` 플래그로 로그인 영구 동결 | 🔵 | 🟢 | - |
| `SecurityResetPasswordAction` | 유저 패스워드 만료 및 초기화 메일 발송 | 🔵 | 🟢 | - |
| `SecurityRevokeOauthTokensAction` | Oauth/Connected App 토큰 강제 회수 | 🔵 | 🟢 | - |
| `SecurityRestrictPermissionAction` | Permission Set Muting 처리 (동적 권한 박탈) | 🔵 | 🟢 | - |
| `SecurityQuarantineProfileAction` | 유저 Profile을 격리 전용 프로파일로 스왑 | 🔵 | 🟢 | - |
| `SecurityUserWarningAction` | LWC 또는 이메일로 경고 메시지 표출/발송 | 🔵 | 🟢 | - |
| `SecurityCreateCaseAction` | 보안팀 조사용 Case(티켓) 자동 생성 | 🔵 | 🟢 | - |

### 3-7. 📡 외부 알림 연동 액션 (Webhook Integration)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityBaseWebhookAction` | 순수 Http 웹훅 조립 뼈대 (Flyweight) | 🔵 | 🟢 | - |
| `SecurityNotifyTeamsAction` | Teams Endpoint로 적응형 카드 알람 발송 | 🔵 | 🟢 | - |
| `SecurityNotifySlackAction` | Slack 웹훅 Endpoint로 보안 알람 발송 | 🔵 | 🟢 | - |
| `SecuritySendToSiemAction` | Splunk/Datadog HEC Endpoint로 로그 포워딩 | 🔵 | 🟢 | - |
| `SecurityNotifyManagerEmailAction` | 상위 관리자(Manager)에게 긴급 이메일 발송 | 🔵 | 🟢 | - |
| `SecurityTeamsPayloadBuilder` | Teams 다이나믹 버튼 카드 렌더링 헬퍼 | 🔵 | 🟢 | - |
| `SecurityNotifyUtil` | 비동기 알림/콜백 발송 공통 유틸리티 | 🔵 | 🟢 | - |

### 3-8. ↩️ 양방향 소통 및 UI 채널 (Inbound & UI Channel)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityDashboardController` | LWC 보안 대시보드 API (수동 방어 위임) | 🔵 | 🟢 | - |
| `SecurityDemoController` | LWC 시뮬레이터에서 모의 이벤트 발행 API | 🔵 | 🟢 | - |
| `IF_SecurityActionController` | Site(Guest)를 통한 외부 버튼 클릭 REST 진입점 | 🔵 | 🟢 |  `SecurityInboundRestController`  `SecurityWebhookEndpoint` |
| `SecurityActionRequest_tr` | `SecurityActionRequest__e` 이벤트의 실행 핸들러 | 🔵 | 🟢 | - |
| `IInboundAction` | 외부 인바운드 페이로드 처리 인터페이스 | 🔵 | 🟢 | - |
| `SecurityInboundToken` | JWT 서명/시크릿 검증 유틸 | 🔵 | 🟢 | - |
| `SecurityActionInboundHandler` | 외부 Payload 해독 및 내부 Action Routing | 🔵 | 🟢 | - |

### 3-9. 🔧 전역 유틸리티 (Global Utilities)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecuritySoarTrace` | 프레임워크 트레이싱 로그 유틸 | 🔵 | 🟢 | - |

### 3-10. 🚫 SOAR 레거시 브릿지 (Exclude from Package)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityInterfaceBridge` | 액션을 구형 Interface 프레임워크로 전달하는 중계기 | 🔵 (과거) | ❌ |  `SecurityActionDispatcher`  `SecurityLegacyBridge` |
| `SecurityNotifyTeamsLegacyAction` | 구형 설정 기반 Teams 레거시 발송기 | 🔵 (과거) | ❌ | - (삭제 후보) |
| `SecurityIntegrationConfig` | Registry 이전 사용된 구형 메타데이터 조회 더미 | 🔵 (과거) | ❌ | - (삭제 후보) |

### 3-11. ❌ 비 SOAR: 사내 공통 통신 프레임워크 (Exclude)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `InboundRestHandler` | 공통 REST API 처리 범용 래퍼 | ❌ | ❌ | - |
| `InterfaceHandler` | 네이티브 HTTP Request/Response 래퍼 | ❌ | ❌ | - |
| `InterfaceFactory` | Config 설정값을 Callout 객체에 주입하는 팩토리 | ❌ | ❌ | - |
| `InterfaceBatch` | Database.Batchable 통신 모드 | ❌ | ❌ | - |
| `InterfaceQueueable` | System.Queueable 통신 모드 | ❌ | ❌ | - |
| `InterfaceRealTime` | 동기 즉시 통신 모드 | ❌ | ❌ | - |
| `InterfaceBizInfo` | 통신 DTO (Data Transfer Object) | ❌ | ❌ | - |
| `InterfaceBatchBizInfo` | 배치 통신 전용 DTO | ❌ | ❌ | - |
| `InterfaceQueueableBizInfo` | 큐어블 통신 전용 DTO | ❌ | ❌ | - |
| `InterfaceTeamsNotifier` | Interface 패키지 소속 구형 알림 유틸 | ❌ | ❌ | - (삭제 후보) |
| `IInterfaceExecutor` | 외부 통신 규격 인터페이스 | ❌ | ❌ | - |

### 3-12. ❌ 비 SOAR: 트리거 프레임워크 & 공통 유틸 (Exclude)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `TriggerHandler` | 공용 Trigger 제어(바이패스) 프레임워크 | ❌ | ❌ | - |
| `ITrigger` | 트리거 인터페이스 | ❌ | ❌ | - |
| `ITriggerHandler` | 트리거 핸들러 인터페이스 | ❌ | ❌ | - |
| `Core` | 앱 공통 기반 유틸 | ❌ | ❌ | - |
| `HttpCallOutConsts` | HTTP 통신 상수 정의 | ❌ | ❌ | - |
| `HttpCallOutOrgCache` | HTTP 통신 조직 캐시 유틸 | ❌ | ❌ | - |
| `SystemSettingsService` | 시스템 전역 설정 서비스 | ❌ | ❌ | - |
| `UtilString` | 문자열 유틸 | ❌ | ❌ | - |
| `UtilDate` | 날짜 유틸 | ❌ | ❌ | - |
| `UtilDatetime` | 날짜시간 유틸 | ❌ | ❌ | - |
| `UtilDecimal` | 수치 유틸 | ❌ | ❌ | - |
| `UtilEncoding` | 인코딩 유틸 | ❌ | ❌ | - |
| `UtilHttp` | HTTP 헬퍼 유틸 | ❌ | ❌ | - |
| `UtilList` | 리스트 유틸 | ❌ | ❌ | - |
| `UtilMap` | 맵 유틸 | ❌ | ❌ | - |
| `UtilObject` | 오브젝트 유틸 | ❌ | ❌ | - |
| `UtilOrg` | 조직 정보 유틸 | ❌ | ❌ | - |
| `UtilQuery` | 쿼리 유틸 | ❌ | ❌ | - |
| `UtilRelatedList` | 관련 목록 유틸 | ❌ | ❌ | - |
| `UtilRelatedListParameters` | 관련 목록 파라미터 VO | ❌ | ❌ | - |
| `UtilSObject` | SObject 유틸 | ❌ | ❌ | - |
| `UtilSchema` | 스키마 유틸 | ❌ | ❌ | - |
| `UtilTrigger` | 트리거 유틸 | ❌ | ❌ | - |
| `UtilUser` | 유저 정보 유틸 | ❌ | ❌ | - |
| `UtilWithoutSharing` | Without Sharing 컨텍스트 유틸 | ❌ | ❌ | - |

### 3-13. ❌ 비 SOAR: 비즈니스 로직 (Exclude)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `AccountController` | Account 화면 LWC 컨트롤러 | ❌ | ❌ | - |
| `AuditMailService` | 감사 이메일 발송 서비스 | ❌ | ❌ | - |
| `CaseViewHandlerController` | Case 뷰 LWC 컨트롤러 | ❌ | ❌ | - |
| `CommonUtilController` | 범용 화면 유틸 컨트롤러 | ❌ | ❌ | - |
| `CommonUtilCustomController` | 커스텀 범용 유틸 컨트롤러 | ❌ | ❌ | - |
| `ContactUsController` | 고객 문의 LWC 컨트롤러 | ❌ | ❌ | - |
| `CustomRichTextController` | 커스텀 리치텍스트 LWC 컨트롤러 | ❌ | ❌ | - |
| `EmailConfigController` | 이메일 설정 LWC 컨트롤러 | ❌ | ❌ | - |
| `EmailHandler` | 이메일 서비스 핸들러 | ❌ | ❌ | - |
| `IF_S3FileController` | AWS S3 파일 연동 REST | ❌ | ❌ | - |
| `KakaoMapController` | 카카오맵 연동 LWC 컨트롤러 | ❌ | ❌ | - |
| `New_PMS_ResourceManagementController` | PMS 리소스 관리 (신규) | ❌ | ❌ | - |
| `PMS_ResourceManagementController` | PMS 리소스 관리 (구형) | ❌ | ❌ | - |
| `OpptyProductController` | Opportunity 제품 컨트롤러 | ❌ | ❌ | - |
| `S3ObjectController` | S3 오브젝트 관리 컨트롤러 | ❌ | ❌ | - |

### 3-14. ❌ 비 SOAR: 테스트 클래스 (Exclude — 패키지용 테스트는 별도 작성)

| Class Name | 설명 및 역할 | SOAR | Pkg | 💡 Rename To-Be |
| :--- | :--- | :---: | :---: | :--- |
| `SecurityActionsTest` | SOAR 액션 통합 테스트 (리팩토링 전 구형) | 🔵 | ❌ | - (패키지용 신규 작성) |
| `InterfaceBatchImplTest` | Interface Batch 테스트 | ❌ | ❌ | - |
| `InterfaceBatchTest` | Interface Batch 테스트 | ❌ | ❌ | - |
| `InterfaceFactoryTest` | Interface Factory 테스트 | ❌ | ❌ | - |
| `InterfaceQueueableTest` | Interface Queueable 테스트 | ❌ | ❌ | - |
| `InterfaceRealTimeTest` | Interface RealTime 테스트 | ❌ | ❌ | - |
| `TestInterfaceBatchImpl` | Interface Batch 구현 테스트 | ❌ | ❌ | - |
| `HttpCallOutConsts_test` | HTTP 상수 테스트 | ❌ | ❌ | - |
| `HttpCallOutOrgCache_test` | HTTP 캐시 테스트 | ❌ | ❌ | - |
| `ChangePasswordControllerTest` | 비밀번호 변경 테스트 | ❌ | ❌ | - |
| `ForgotPasswordControllerTest` | 비밀번호 분실 테스트 | ❌ | ❌ | - |
| `MyProfilePageControllerTest` | 프로필 페이지 테스트 | ❌ | ❌ | - |
| `SiteLoginControllerTest` | 사이트 로그인 테스트 | ❌ | ❌ | - |
| `SiteRegisterControllerTest` | 사이트 레지스터 테스트 | ❌ | ❌ | - |

---

## 📊 리네이밍 대상 요약 (Rename Summary)

참조 문서 `11_COMPONENT_DICTIONARY_AND_AUDIT.md`와 교차 분석 결과, 아래와 같이 리네이밍 후보가 분류됩니다.

### 🔵 SOAR 패키지 대상 중 리네이밍 대상

| As-Is | 💡 To-Be 추천 | 사유 |
| :--- | :--- | :--- |
| `SecurityGuard` |  `SecurityPolicyEvaluator`  `SecurityThreatAnalyzer`  `SecurityEventAssessor` | God Class. 이름이 "경비원"이지만 실제로는 정책 평가·위협 분석·이벤트 판단까지 하는 다기능 클래스 |
| `SecurityValidator` |  `SecurityAccessChecker`  `SecurityPermissionValidator` | "검증기"라는 모호한 이름이 실제 접근 제어/관리자 예외 검증 역할을 반영 못함 |
| `IF_SecurityActionController` |  `SecurityInboundRestController`  `SecurityWebhookEndpoint` | `IF_` 접두어가 Interface 레거시 네이밍 잔재. REST 컨트롤러 역할에 맞게 변경 권고 |
| `SecurityAuditLog__c` | `SecurityUserState__c` | "감사 로그"가 아니라 유저별 누적 상태(AlertCount) 보관소이므로 역할과 불일치 |
| `SecurityInboundConfig__mdt` | `SecurityGlobalConfig__mdt` | "인바운드 설정"인데 실제 킬스위치·스로틀 등 글로벌 환경 전체를 관리 |

### 🔴 비 SOAR 중 리네이밍 대상 (패키지 미포함이지만 참고)

| As-Is | 💡 To-Be 추천 | 사유 |
| :--- | :--- | :--- |
| `SecurityInterfaceBridge` |  `SecurityActionDispatcher`  `SecurityLegacyBridge` | 역할(액션 전달)과 이름(브릿지)의 괴리 |
| `SecurityIntegration__mdt` | `SecurityActionRoute__mdt` | "통합"이 아니라 "액션-큐 라우팅 매핑" 역할 |

> [!NOTE]
> `Interface*` 계열 클래스(`InterfaceHandler`, `InterfaceFactory` 등)는 인바운드/아웃바운드 양방향 통신을 모두 처리하는 범용 프레임워크이므로, `Interface`라는 네이밍이 오히려 적합합니다. `HttpCallout`으로 변경 시 아웃바운드 전용으로 오해될 수 있어 **리네이밍 대상에서 제외**합니다.

---

## 💡 종합 결론

* **`[Package 🟢]`** 라벨이 붙은 컴포넌트만 물리적으로 분리하여 패키지 빌드 큐를 구성합니다.
* 리네이밍은 **패키지 추출과 동시에** 또는 **추출 직후** 한꺼번에 진행하면 가장 효율적입니다.
* 기존 테스트 클래스(`SecurityActionsTest`)는 구형 구조 기반이므로, 패키지용 신규 Test Class를 별도 작성합니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
