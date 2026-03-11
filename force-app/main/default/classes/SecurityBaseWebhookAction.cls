/**
* @Author            : jh.jung
* @Description 		 : 모든 외부 연동(Slack, Teams, 이메일 시스템 등)의 통신 기반이 되는 Flyweight 패턴 클래스
* 내부 커스텀 통신 인터페이스(Interface__c) 종속성을 모두 제거하고 순수 Sfdx 패키징이 
* 가능하도록 Salesforce 표준 Http 및 Named Credential 방식을 채택합니다.
* @Target            : 
* @Modification Log
* Ver      Date            Author           Modification
* ===================================================================================
* 1.0      2026-03-11      jh.jung           Created - Tier 2 Flyweight Webhook Action
*/
public virtual class SecurityBaseWebhookAction extends SecurityBaseAction {
    
    // 서브 클래스가 구현해야 하는 훅 메서드
    protected virtual String getActionType() {
        return 'UNKNOWN_WEBHOOK';
    }

    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        String actionType = getActionType();
        
        // 1. 메타데이터에서 연동 설정 가져오기
        List<SecurityWebhookConfig__mdt> configs = [
            SELECT Endpoint__c, IsActive__c 
            FROM SecurityWebhookConfig__mdt 
            WHERE ActionType__c = :actionType AND IsActive__c = true
            LIMIT 1
        ];

        if (configs.isEmpty()) {
            SecuritySoarTrace.log('SecurityBaseWebhookAction.doExecute.Skipped', new Map<String, Object>{
                'reason' => 'No active SecurityWebhookConfig__mdt found for ' + actionType
            });
            return;
        }

        String endpointConfig = configs[0].Endpoint__c; // 이제는 Named Credential Name 이나 URL 로 사용됨

        if (String.isBlank(endpointConfig)) {
            SecuritySoarTrace.log('SecurityBaseWebhookAction.doExecute.Error', new Map<String, Object>{
                'reason' => 'Endpoint__c is empty for ' + actionType
            });
            return;
        }

        // 2. 표준 Http Callout 구성
        HttpRequest req = new HttpRequest();
        
        // Named Credential 지원: 'callout:MyNamedCredential' 형태이거나 완전한 'https://...' URL 파싱
        if (endpointConfig.startsWith('callout:') || endpointConfig.startsWith('http')) {
            req.setEndpoint(endpointConfig);
        } else {
            // 구 버전 호환성 혹은 유저 편의를 위해 'callout:' prefix 자동 부착
            req.setEndpoint('callout:' + endpointConfig);
        }
        
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setBody(originalPayloadJson);

        // 3. 발송 (Queueable 컨텍스트인 ActionExecutor 내부에서 실행되므로 안전함)
        Http http = new Http();
        try {
            HttpResponse res = http.send(req);
            
            SecuritySoarTrace.log('SecurityBaseWebhookAction.doExecute.Success', new Map<String, Object>{
                'actionType' => actionType,
                'endpoint' => endpointConfig,
                'statusCode' => res.getStatusCode(),
                'status' => res.getStatus()
            });

        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityBaseWebhookAction.doExecute.Error', new Map<String, Object>{
                'actionType' => actionType,
                'endpoint' => endpointConfig,
                'error' => e.getMessage(),
                'stack' => e.getStackTraceString()
            });
        }
    }
}
