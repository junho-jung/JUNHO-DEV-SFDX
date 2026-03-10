# 🌟 17. 궁극의 확장성: Zero-Code 정책 및 액션 등록 (Tier 3 Refactoring)

*"지금 리팩토링 다 하면 기능 추가할 때 비즈니스 로직 담당하는 클래스 만들고 메타데이터에 추가만 하면 동작하나? 액션 등록은 그런데 정책(Policy) 등록은 코드 수정이 필요하지 않아? 팀즈(Teams)랑 연결된 기능이면 코드 수정이 필요하고... 이것도 메타데이터로만 관리하도록 리팩토링 가능해?"*

**뛰어난 통찰력입니다!** 사용자님의 질문은 현재 아키텍처(Tier 1, 2)가 가진 마지막 한계점을 정확히 짚어냈습니다. 현재 구조에서는 새로운 인터셉터(정책 감지기)를 달거나, 완전히 새로운 포맷의 API(Teams)를 쏠 때 결국 Apex 클래스를 최소 1개는 '명시적으로' 개발해야 합니다. 

본 문서는 이러한 남은 1%의 하드코딩마저 완전히 없애버려, 개발자 없이 어드민만으로 모든 것을 확충할 수 있는 **[Tier 3: 100% Zero-Code Extensibility]** 설계 방안을 다룹니다.

---

## 🎯 1. 정책(Policy) 등록의 Zero-Code화: Universal Interceptor

현재는 특정 이벤트(예: Report 엑스포트)를 잡으려면 `TxnSecurity.EventCondition`을 상속받는 `EM_SecurityReportInterceptor.cls` 라우팅 코드를 짜서 분기 처리를 해줘야 합니다. 이를 **메타데이터가 스스로 검사 조건(Criteria)을 쥐고 있는 구조**로 혁신합니다.

### 💡 해결책: `SecurityUniversalInterceptor.cls` + 조건식 메타데이터

하나의 거대한 만능 인터셉터(`UniversalInterceptor`)만 표준 Transaction Security 리스너에 달아둡니다. 이 인터셉터는 하드코딩된 `if`문 대신, 새롭게 정의될 **`SecurityPolicyCriteria__mdt`** 메타데이터를 Loop 돌면서 동적으로 룰을 검사합니다.

#### [To-Be] 메타데이터 구조 (No-Code Rule Engine)
* **Metadata**: `SecurityPolicyCriteria__mdt`
* **Fields**:
  * `PolicyCode__c`: `MASS_REPORT_EXPORT` (부모 정책 매핑)
  * `TargetEvent__c`: `ReportEvent` (감지할 이벤트 객체명)
  * `EvaluateField__c`: `QueriedEntities` (검사할 필드명)
  * `Operator__c`: `CONTAINS` (연산자: EQUALS, CONTAINS, GREATER_THAN 등)
  * `Value__c`: `Account` (비교할 값)

#### [To-Be] Universal Interceptor 엔진의 동적 검증 로직
이제 개발자가 인터셉터 클래스를 새로 짤 필요 없이, 만능 엔진이 **메타데이터의 문자열 연산자**를 리플렉션으로 해석해버립니다.

```apex
// SecurityUniversalInterceptor.cls (단 하나만 존재)
public boolean evaluate(SObject event) {
    String eventType = String.valueOf(event.getSObjectType());
    
    // 1. 해당 이벤트 타입(예: ReportEvent)에 걸려있는 모든 메타데이터 룰셋 조회
    List<SecurityPolicyCriteria__mdt> rules = SecurityMetadataRegistry.getCriteria(eventType);
    
    for(SecurityPolicyCriteria__mdt rule : rules) {
        // 2. 이벤트의 실제 필드값 추출
        String actualValue = String.valueOf(event.get(rule.EvaluateField__c)); // 예: "Account, Contact"
        
        // 3. 메타데이터에 적힌 연산자(CONTAINS)에 따라 동적 동적 파싱
        if(rule.Operator__c == 'CONTAINS' && actualValue.contains(rule.Value__c)) {
            // 조건 충족 시 해당 PolicyCode 트리거!
            SecurityAlertPublisher.publish(rule.PolicyCode__c, event);
        }
    }
    return false;
}
```
### ⚠️ [중점 고려사항] 메타데이터 정책 관리의 "오퍼레이션 한계점 (Operational Trade-off)"

사용자 님께서 매우 예리하게 지적하신 것처럼, **"모든 이벤트(10여 개)의 조건을 메타데이터 1개로 감지(Evaluate)하는 것"** 은 개발 공수를 0으로 만들지만, 역으로 **어드민(Admin)의 오퍼레이션 관리 난이도를 수직 상승**시킵니다.

**[발생 가능한 관리 복잡도 예시]**
1. **필드 참조의 복잡성**: 단순 텍스트 비교(`Account` 포함 여부)는 쉽지만, **RecordType ID**, **Profile Name**, **특정 Role Hierarchy** 등 관계형(Relational) 조건을 메타데이터의 `EvaluateField__c` 텍스트 하나로 매핑하기는 거의 불가능에 가깝습니다.
2. **다중 조건(AND/OR)의 지옥**: "만약 레코드타입이 A이거나 B인데, 시간은 새벽 2시이고, 파일 확장자가 PDF일 때" 라는 복합 룰을 메타데이터 Table로 구현하려면 `Condition Logic (1 AND (2 OR 3))` 같은 복잡한 Formula 파서를 직접 만들어야 합니다.
3. **이벤트 스키마 종속성**: `ReportEvent`와 `ApiEvent`는 서로 가지고 있는 필드 구조가 완전히 다릅니다. 관리자가 메타데이터에 오타(`QuriedEntities` 등)를 내면 즉시 런타임 NullPointerException이 발생할 위험이 큽니다.

#### 💡 현실적인 타협점 (The Hybrid Approach)
이러한 한계를 극복하기 위해, 글로벌 마켓(ISV) 수준의 완벽한 룰 엔진을 자체 구축하지 않는 이상 **"하이브리드(Hybrid) 접근법"** 을 권장합니다.

1. **[정책 판단 로직 (Policy Detection)] ➡️ 기존처럼 Apex 뼈대 유지 (Tier 2)**
   * 조건식이 복잡하게 얽히는 `EM_SecurityReportInterceptor` 류의 클래스 내부는 **전문 개발자가 Apex로 안전하게 Type-Safe하게 구현**하도록 남겨둡니다. 
   * (장점: 오류 방지, 복합 조건 처리에 압도적으로 유리)
2. **[이후 라우팅 및 연동 (Action & Routing)] ➡️ 100% Zero-Code 메타데이터 전환 (Tier 3)**
   * 감지 이후에 "누구한테 보낼지(Slack/Teams), 몇 번 누적 시 차단할지, 어떤 포맷의 메시지(JSON)를 쏠지" 등은 철저히 메타데이터(`GenericWebhook`)에 맡겨 No-Code를 달성합니다.

결론적으로, 정책(Policy)의 **'감지 조건(If)'** 은 Apex의 견고함에 맡기고, 감지 이후의 **'처벌(Then)'** 과정만 100% 메타데이터(Zero-Code)로 분리하는 것이 가장 유지보수하기 쾌적하고 강력한 아키텍처 비율이 될 것입니다.

---

## 🌐 2. API 액션(Webhook) 등록의 Zero-Code화: Generic Callout Template

사용자님의 지적대로, Slack 대신 Teams로 쏘고 싶다면 `SecurityNotifyTeamsAction.cls` 파서를 어쩔 수 없이 짜야했습니다. (페이로드 형태 `{"text":...}` 가 시스템마다 다르기 때문이죠). 이를 **템플릿 치환(Merge Field)** 방식으로 혁신합니다.

### 💡 해결책: `SecurityGenericWebhookAction.cls` + Payload 템플릿 메타데이터

모든 API 호출용 액션을 통합할 단 하나의 만능 발사기(`GenericWebhook`)를 만듭니다. 이 발사기는 어드민이 정의한 **JSON 템플릿 텍스트** 안의 변수(`{UserId}`)를 실시간으로 치환(Replace)하여 쏘게 됩니다.

#### [To-Be] 메타데이터 구조 (Payload Template)
기존 `HttpCalloutConfig__mdt` 객체에 템플릿 필드를 2개 추가합니다.
* **Fields**:
  * `NamedCredential__c`: `NC_Teams_Webhook`
  * `Method__c`: `POST`
  * `HttpHeaderOverrides__c`: `{"Content-Type": "application/json"}`
  * `PayloadTemplate__c`: 
    ```json
    {
      "title": "🚨 보안 위협 감지",
      "text": "유저 ID: {UserId} 가 {PolicyCode} 룰을 위반했습니다. \n행위: {ActionType}"
    }
    ```

#### [To-Be] Generic Webhook Action의 동적 조립 로직
이제 Teams든, Discord든, 사내 ERP든 **Endpoint와 JSON 뼈대만 다르면 개발자 없이 100% 무한 확장**됩니다.

```apex
// SecurityGenericWebhookAction.cls (단 하나만 존재)
public override void execute(Map<String, Object> params) {
    HttpCalloutConfig__mdt config = (HttpCalloutConfig__mdt)params.get('interfaceConfig');
    
    // 1. 프레임워크가 준 파라미터(변수) 추출
    String targetUserId = (String)params.get('targetUserId');
    String policyCode = (String)params.get('policyCode');
    
    // 2. 관리자가 짜놓은 JSON 템플릿 로드
    String bodyPayload = config.PayloadTemplate__c;
    
    // 3. Merge Field 실시간 치환 (Zero-Code의 핵심)
    bodyPayload = bodyPayload.replace('{UserId}', targetUserId);
    bodyPayload = bodyPayload.replace('{PolicyCode}', policyCode);
    
    // 4. 동적 Callout 발사
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:' + config.NamedCredential__c);
    req.setMethod(config.Method__c);
    req.setBody(bodyPayload);
    
    new Http().send(req);
}
```
👉 **비즈니스 효과**: "내일부터 카카오톡 웍스(Kakao Work) 채널로도 보안 로그를 쏴주세요" 라는 결재가 올라오면, **개발자는 코드를 짤 필요가 없습니다.** 어드민이 `PayloadTemplate__c` 에 카카오톡 JSON 스펙만 넣고 `HttpCalloutConfig__mdt` 메타데이터 레코드만 생성하면 끝입니다.

---

## 🏆 결론: 100% No-Code SOAR 시스템의 완성

사용자님이 상상하신 그대로입니다. **Tier 3 리팩토링(Universal Rule Engine + Generic Webhook Template)** 이 도입되면 프레임워크는 궁극의 경지에 오릅니다.

1. **새로운 방어 룰(Policy) 추가**: 개발 X, 메타데이터 연산자(CONTAINS 등) 추가.
2. **새로운 API 채널(액션) 연동**: 개발 X, 메타데이터에 JSON 템플릿(Payload) 복사 붙여넣기.

본 리팩토링 방안은 앞선 05번(OCP 팩토리) 문서를 넘어서는 **데이터 주도 아키텍처(Data-Driven Architecture)** 의 완전판으로, 패키징하여 오픈소스로 공개 시 글로벌 Salesforce 시장에서도 극찬받을 구조적 파워를 갖게 될 것입니다.

[⬅️ 메인 문서를 확인하려면 여기를 누르세요.](../README.md)
