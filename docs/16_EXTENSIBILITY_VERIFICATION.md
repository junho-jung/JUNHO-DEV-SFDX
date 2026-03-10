# ✅ 16. 신규 기능 추가(확장성) 완벽 검증 시뮬레이션 (Extensibility Verification)

사용자(개발자/어드민)가 질문한 **"리팩토링이 전부 끝나면, 진짜로 코어 코드 수정 없이 Action 클래스 1개 만들고 메타데이터만 띡 추가하면 알아서 돌아가나요?"** 에 대한 해답과, 실제 시스템 파이프라인 관통(Trace) 검증 리포트입니다.

결론부터 말씀드리면 **"네, 단 1줄의 프레임워크 코어 수정 없이 100% 자동 동작합니다."**
이것이 05번 문서(리팩토링 제안)에서 강조했던 **개방-폐쇄 원칙(OCP, Open-Closed Principle)** 의 궁극적 달성 형태입니다.

아래 시뮬레이션을 통해 시스템 로직을 처음부터 끝까지 따라가 보겠습니다.

---

## 🚀 [가상 시나리오] "ERP 계정 자동 잠금(ERP_LOCK)" 기능 신규 개발

보안팀에서 **"심야 시간에 세일즈포스 대량 조회 패턴(NIGHT_MASS_API)이 터지면, 사내 ERP 접속 계정도 자동으로 잠가주세요!"** 라는 신규 요구사항을 가져왔습니다.

### 1️⃣ 개발자의 작업 (단 1개 클래스 생성)

개발자는 기존 `Security*` 코어 클래스(Guard, Executor, Handler 등)를 절대 건드리지 않습니다. 오로지 외부 연동 로직을 담은 **액션 클래스 1개**만 신규로 만듭니다.

```apex
// [신규 파일] SecurityLockErpUserAction.cls
public with sharing class SecurityLockErpUserAction extends SecurityBaseAction {
    
    public override void execute(Map<String, Object> params) {
        // 1. 패러미터에서 공격자(타겟) 정보 추출
        String targetUserId = (String)params.get('targetUserId');
        
        // 2. 외부 ERP 연동 API 호출 (Named Credential 활용)
        HttpCalloutConfig__mdt config = (HttpCalloutConfig__mdt)params.get('interfaceConfig');
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + config.NamedCredential__c + '/api/v1/auth/lock');
        req.setMethod('POST');
        req.setBody('{"salesforce_uid" : "' + targetUserId + '"}');
        
        HttpResponse res = new Http().send(req);
        
        // 3. SOAR 공통 로그에 결과 기록
        SecuritySoarTrace.log('SecurityLockErpUserAction.execute', new Map<String, Object>{
            'UserId' => targetUserId,
            'StatusCode' => res.getStatusCode()
        });
    }
}
```

### 2️⃣ 어드민의 작업 (메타데이터 3개 맵핑)

개발자가 코드를 라이브에 배포하면 끝입니다. 이제 어드민(Admin)이 **설정(Setup) > Custom Metadata Types** 화면에서 '마우스 클릭'으로 이 Action을 SOAR 프레임워크 파이프라인에 조립합니다.

1. **`HttpCalloutConfig__mdt` (통신 세팅)** 생성 
   * **Label**: `IF_ERP_Security` 
   * **설정**: Named Credential 부분에 ERP와 연결해둔 인증 정보 입력.
2. **`SecurityActionRoute__mdt` (프레임워크에 액션 등록)** 생성 (구 SecurityIntegration)
   * **ActionType__c**: `ERP_LOCK` (내가 마음대로 지은 액션 식별자)
   * **Mode__c**: `QUEUEABLE` (Callout이므로 비동기로 돌아야 함)
   * **ActionClassName__c**: `SecurityLockErpUserAction` (개발자가 만든 클래스명 입력 - 핵심🔥)
   * **InterfaceId__c**: `IF_ERP_Security` (1번에서 만든 것 맵핑)
3. **`SecurityPolicy__mdt` (정책에 액션 끼워넣기)** 수정
   * 기존 `NIGHT_MASS_API` 정책 레코드를 엽니다.
   * `ActionCritical__c` 필드 값에 콤마(,)를 찍고 방금 만든 `ERP_LOCK`을 추가합니다.
   * *예: `NOTIFY_SLACK, FREEZE_USER, ERP_LOCK`*

---

## 🔍 [내부 동작 검증] 프레임워크는 이것을 어떻게 소화하는가?

이제 실제로 심야 시간에 타겟팅된 위협 유저가 나타났다고 가정하고, 프레임워크 중심부를 관통해봅니다.

### Step 1. 감지와 정책 매핑 (`SecurityPolicyEvaluator`)
1. 인터셉터가 이벤트를 캡처하여 `SecurityAlertHandler`에게 던집니다.
2. 정책 엔진은 `NIGHT_MASS_API` 정책 메타데이터를 캐시에서 읽어옵니다.
3. 임계치 초과를 확인하고, 조치 목록 문자열을 스플릿하여 `['NOTIFY_SLACK', 'FREEZE_USER', 'ERP_LOCK']` 3개의 개별 처리 지시를 만듭니다.

### Step 2. 라우팅 및 팩토리 빌드 (`SecurityActionBuilder` - 리팩토링의 핵심)
1. 프레임워크는 라우터(`SecurityActionRoute__mdt`)에서 `ActionType = 'ERP_LOCK'` 인 레코드를 뒤집니다.
2. 앗! 레코드에 **저장된 클래스 이름**이 `SecurityLockErpUserAction`인 것을 확인합니다.
3. **[🔥 리팩토링 Magic]** 팩토리 로직은 낡은 `switch-case`문이 아니라, **리플렉션(Reflection)** 을 사용합니다.
   ```apex
   // 동적 객체 생성 (if문, switch 없음. 무조건 1줄로 끝남)
   Type t = Type.forName(routeMdt.ActionClassName__c); 
   ISecurityAction myNewAction = (ISecurityAction) t.newInstance();
   ```
4. 프레임워크는 이 액션이 기존 뼈대인지 듣보잡인지 모른 채, 그저 `ISecurityAction` 규격을 준수하는 객체 덩어리로 메모리에 찍어냅니다.

### Step 3. 큐 라우팅 및 최종 실행 (`SecurityActionExecutor`)
1. 익스큐터는 방금 메모리에서 동적 생성한 객체(`myNewAction`)를 넘겨받습니다.
2. 라우터 메타데이터에 적혀있던 방식이 `Mode__c = QUEUEABLE` 임을 확인합니다.
3. 곧바로 비동기 큐 잡(`System.enqueueJob()`)으로 해당 객체의 `execute()` 메소드를 위임 발사합니다.
4. 개발자가 작성했던 콜아웃 코드가 비동기 스레드에서 안전하게 돌며 ERP를 잠그고 끝납니다.

---

## 🏆 결론 (The Verdict)

위 검증 워크스루(Walkthrough)에서 보듯, 새로운 `ERP_LOCK` 이라는 파생 비즈니스 로직을 하나 붙이기 위해 기존 `SecurityActionExecutor`나 `SecurityActionBuilder` 등을 **단 한 줄도 수정하지 않았습니다.** 

새로운 것을 추가할 때(Open), 기존 코드를 열어서 뜯어고칠 필요가 없는(Closed) **OCP 원리**가 리플렉션과 메타데이터의 조합으로 완벽히 증명되었습니다. 

이것이 이번 아키텍처 재설계(10~15번 문서 작업)의 최종 지향점이며 프레임워크가 가져야 할 진정한 파워입니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
