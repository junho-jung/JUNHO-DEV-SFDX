# SOAR Framework: AppExchange Packaging Exclusion Guide

본 문서는 SOAR(Security Orchestration, Automation, and Response) 프레임워크를 **독립적인 관리형 패키지(Managed Package)**로 빌드하여 AppExchange 등에 등재할 때, **반드시 패키지에서 제외(Exclude)해야 하는 레거시 종속성 목록**을 정의합니다.

Tier 2 리팩토링의 핵심 목표인 '100% 독립성(Zero Dependency)'을 유지하기 위해 아래 목록의 파일들은 절대 패키징 대상에 포함시키면 안 됩니다.

---

## 🚫 절대 포함 금지 목록 (Must Exclude)

### 1. Legacy `Interface` 통신 프레임워크 전반
과거 사내망 연동을 위해 구축되었던 거대한 커스텀 통신 프레임워크입니다. 이 파일들이 패키지에 하나라도 섞여 들어가면 SOAR 엔진이 무거워지고, 패키지 설치 고객의 환경을 오염시킵니다.

**Custom Objects & Metadata:**
- `Interface__c` (객체 및 연관된 모든 Custom Fields, List Views)
- `InterfaceLog__c` (객체 및 연관된 모든 Custom Fields, List Views)
- `InterfaceConfig__mdt` (객체 및 레코드)
- `SecurityIntegration__mdt` (객체 및 레코드) : 기존 방식 브리지 라우팅을 위한 오브젝트이므로 제외. SOAR 패키지 전용 웹훅은 `SecurityWebhookConfig__mdt`를 사용해야 합니다.

**Apex Classes & Triggers:**
- `InterfaceHandler.cls`
- `InterfaceFactory.cls`
- `IInterfaceExecutor.cls` (인터페이스)
- `InterfaceRealTime.cls`, `InterfaceQueueable.cls`, `InterfaceBatch.cls` (및 Test 클래스들)
- `InterfaceTeamsNotifier.cls` 등 `Interface` 접두어가 붙은 모든 커스텀 클래스
- `HttpCallOutConsts.cls`, `HttpCallOutOrgCache.cls`

---

### 2. `SecurityInterfaceBridge.cls` (중요)
- **설명:** 과거 SOAR 엔진에서 내부 `Interface__c` 통신망을 호출할 때 썼던 징검다리 클래스입니다.
- **이유:** 해당 클래스 내부에서 `InterfaceConfig__mdt` 및 `InterfaceFactory`를 참조하기 때문에, 이 클래스를 패키지에 넣는 순간 위의 1번(Legacy Interface 로직 전체) 항목들이 오류 방지를 위해 강제로 패키지에 딸려 들어가게 됩니다.
- **조치:** 패키지 본체에서는 제외되며, 설치 후 고객사가 사내 통신망과 SOAR를 억지로 연동할 때만 '로컬 엑스텐션(Local Unmanaged Extension)' 용도로 직접 생성해서 써야 합니다.

---

### 3. 기타 SOAR와 무관한 사내 레거시 시스템 및 앱
SOAR 프레임워크와 직접적인 연관이 없는 기존 SI 프로젝트 산출물들입니다.

**Custom Objects:**
- `ContactUs__c`
- `Department__c`, `Employee__c`
- `MonthlyEstimation__c`, `ProjectMember__c`
- `S3Files__c`
- `SalesReport__c`

**Apex Classes:**
- `KakaoMapController.cls`
- `S3ObjectController.cls`, `IF_S3FileController.cls`
- `PMS_ResourceManagementController.cls`
- `OpptyProductController.cls`

---

## ✅ 패키지 내 필수 포함 대상 요약 (Must Include)

SOAR 패키징 시 **반드시 포함되어야 하는** 뼈대(Core) 요소들입니다.

**SOAR 핵심 Metadata & 객체:**
- `SecurityPolicy__mdt` (보안 정책 로직)
- `SecurityInboundAction__mdt` (액션 맵핑 로직)
- `SecurityInboundConfig__mdt` (엔진 기본 설정)
- `SecurityWebhookConfig__mdt` (독립 외부 알림 전용 설정 - **신규**)
- `SecurityActionLog__c`, `SecurityAuditLog__c`, `SecurityInboundTokenUsed__c` (감사 및 로그 객체)
- `SecurityAlert__e`, `SecurityActionRequest__e` (플랫폼 이벤트)

**SOAR 핵심 Apex 프레임워크:**
- `SecurityGuard.cls` (이벤트 퍼사드 계층)
- `EM_Security***Interceptor.cls` (인터셉터들)
- `SecurityActionFactory.cls`, `SecurityAlertHandler.cls` (동적 할당 및 책임 연쇄)
- `SecurityAlertPublisher.cls`, `IEventExtractor.cls`, `***EventExtractor.cls` (다형성 이벤트 추출)
- `SecurityBaseAction.cls`, `SecurityBaseWebhookAction.cls` (Flyweight 베이스 클래스 - **중요**)
- `SecurityMetadataRegistry.cls` (싱글톤 캐시 관리자)
- 커스텀 알림/행동 클래스들 (`SecurityNotifySlackAction.cls`, `SecurityFreezeUserAction.cls` 등 - 브리지를 참조하지 않는 것들)

---

### 결론 요약

> **" `Interface` 라는 단어가 이름에 포함되거나, `SecurityInterfaceBridge.cls`를 참조하는 코드는 SOAR 관리형 패키지에 단 한 줄도 들어가선 안 됩니다. 오직 `Security` 접두어로 시작하는 순수 코어 위주로 엮어내야 합니다. "**
