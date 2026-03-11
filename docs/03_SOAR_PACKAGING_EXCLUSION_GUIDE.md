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

---

## 💡 [FAQ] 표준 웹훅 vs 레거시 브릿지 연동 방식 비교

SOAR 패키지를 설치한 후 외부 알림을 보낼 때, **표준 웹훅**을 쓸 것인지 **기존 사내망 브릿지**를 쓸 것인지에 따라 아키텍처 상속(extends) 계층이 완전히 달라집니다. 

가장 헷갈리기 쉬운 질문: *"Base 클래스(`SecurityBaseWebhookAction`)의 `doExecute`를 오버라이드해서 브릿지랑 연결하는게 맞나요?"*
**정답:** ❌ **아닙니다.** 브릿지를 태울 때는 `SecurityBaseWebhookAction`을 무시하고, 아예 가장 높은 조상인 **`SecurityBaseAction`**을 직접 상속받아야 합니다.

### 1. [SOAR 표준] `SecurityBaseWebhookAction` 방식 (패키지 포함 O)
SOAR 코어 엔진이 스스로 `HttpRequest`를 던지는 방식입니다. `SecurityWebhookConfig__mdt`를 쳐다봅니다.

```apex
/**
 * [표준 방식]
 * 순수하게 외부 URL(Slack, Teams 등)로 Callout 할 때 사용.
 * SecurityBaseWebhookAction이 HTTP 콜아웃 로직을 이미 다 가지고 있으므로,
 * 자식 클래스는 "내 액션 이름이 뭔지"만(ActionType) 리턴해주면 됩니다.
 */
public with sharing class SecurityNotifySlackAction extends SecurityBaseWebhookAction {
    
    // 이 텍스트로 SecurityWebhookConfig__mdt에서 Endpoint URL을 찾아 알아서 HTTP 전송합니다.
    protected override String getActionType() {
        return 'NOTIFY_SLACK';
    }
}
```

### 2. [확장] `SecurityInterfaceBridge` 레거시 연동 방식 (패키지 포함 X, 고객사 Local Org 직접 생성)
사내 `Interface__c` 거대한 프레임워크를 태워야 할 때 씁니다. 이때는 HTTP 통신을 '브릿지 너머의 레거시 프레임워크'가 대신 해주므로, 이 클래스에서는 통신 로직(`BaseWebhookAction`)이 필요 없습니다.

```apex
/**
 * [레거시 브릿지 방식]
 * 고객사(Local Org) 환경에서 패키지 외부에 직접 생성하는 언매니지드 클래스.
 * Webhook 전용 베이스가 아니라, 가장 기본 뼈대인 'SecurityBaseAction'을 상속받습니다.
 */
public with sharing class MyLegacyCustomAction extends SecurityBaseAction {
    
    // 이곳에서 doExecute를 직접 오버라이드하여 브릿지를 호출합니다.
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        
        // 1. 필요한 추가 가공이 있다면 여기서 수행

        // 2. SOAR 웹훅 로직을 버리고, 레거시 종속성인 Bridge를 다이렉트로 호출합니다.
        // SecurityIntegration__mdt(Legacy) 테이블을 쳐다보게 됩니다.
        SecurityInterfaceBridge.callForAction('LEGACY_SYSTEM_ALERT', originalPayloadJson);
        
    }
}
```

### 3. [참고] 내부 로직 전용 액션 vs 커스텀 외부 콜아웃 연동 액션 포맷 비교
SOAR 패키지를 설치한 후 고객사가 자유롭게 커스텀 액션을 추가할 때 지켜야 하는 **템플릿(포맷) 가이드**입니다. SFDC 내부 데이터만 조작하느냐, 외부 통신을 동반하느냐에 따라 템플릿과 실행 모드가 다릅니다.

#### A. 내부 로직 전용 액션 (Internal SFDC Logic)
* **특징:** SFDC 레코드 수정, 권한 회수, 프로필 변경 등 트랜잭션 내에서 즉시 완료되는 작업입니다.
* **메타데이터 설정 (\SecurityInboundAction__mdt\):** \ExecutionMode__c\를 **\SYNC\ (권장) 또는 \ASYNC\** 로 설정.

``apex
/**
 * [내부 로직 전용 액션 포맷]
 * 외부 통신이 없으므로 Webhook 베이스가 아닌 가장 근본이 되는 BaseAction을 상속합니다.
 */
public class MyInternalCustomAction extends SecurityBaseAction {
    
    // 이 오버라이드 메서드에 원하는 로직을 작성합니다.
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        
        // Ex) 추출된 Target 유저의 권한셋을 회수하거나 레코드를 업데이트
        if (String.isNotBlank(targetUserId)) {
            User u = [SELECT Id, IsActive FROM User WHERE Id = :targetUserId LIMIT 1];
            u.IsActive = false;
            update u;
        }
        
    }
}
``

#### B. 커스텀 외부 콜아웃 연동 액션 (External Custom Callout Logic)
* **특징:** 표준 웹훅 방식(위 1번 FAQ)만으로는 부족할 때, 즉 커스텀 인증 헤더나 복잡한 전처리 로직이 필요한 외부 API 등을 직접 연동할 때 사용합니다.
* **메타데이터 설정 (\SecurityInboundAction__mdt\):** \ExecutionMode__c\를 **반드시 \ASYNC\** 로 설정! (SFDC는 Trigger 트랜잭션 내부에서 실시간 Callout을 막기 때문입니다.)

``apex
/**
 * [커스텀 콜아웃 연동 액션 포맷]
 * 커스텀 통신이 목적이므로 BaseWebhookAction 대신 BaseAction을 상속받아 HTTP 콜아웃을 직접 구현합니다.
 */
public class MyExternalCustomAction extends SecurityBaseAction {
    
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        
        // 1. 여기서 추출된 데이터를 바탕으로 복잡한 외부 전송용 JSON Payload 조립
        String customJsonBody = '{ "user": "' + targetUserId + '", "alert": "High Risk Event" }';
        
        // 2. 외부 Callout 진행 (이 코드는 이미 ASYNC 큐에이블 안에서 실행 중이므로 Callout 에러가 나지 않음)
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:MyCustomLegacyAPI');
        req.setMethod('POST');
        req.setBody(customJsonBody);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // (참고) 만약 레거시 브릿지를 연동할거라면 위 HTTP 코드를 전부 지우고 아래 호출만 쓰면 됩니다.
        // SecurityInterfaceBridge.callForAction('LEGACY_ALERT', originalPayloadJson);
    }
}
``
