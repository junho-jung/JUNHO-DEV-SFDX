/**
 * @Description SOAR 데모 시뮬레이터. LWC 화면에서 시뮬레이터 버튼을 클릭할 때
 *              위조된 SecurityAlert__e 객체를 Publish 하여 코어 엔진을 강제로 구동합니다.
 */
public with sharing class SecurityDemoController {
    
    /**
     * @description 지정된 정책 코드로 모의 이벤트를 반복 투발합니다.
     * @param targetUserId 시뮬레이션 대상 유저 ID
     * @param policyCode 위반할 정책 코드 (예: 'DATA_EXPORT', 'INVALID_LOGIN')
     * @param repeatCount 이벤트를 반복 전송할 횟수 (임계치 테스트용)
     */
    @AuraEnabled
    public static void simulateAlert(String targetUserId, String policyCode, Integer repeatCount) {
        if (repeatCount == null || repeatCount < 1) repeatCount = 1;
        
        List<SecurityAlert__e> eventsToPublish = new List<SecurityAlert__e>();
        
        // 대상 User 정보 조회
        List<User> users = [SELECT Id, Name FROM User WHERE Id = :targetUserId LIMIT 1];
        if (users.isEmpty()) {
            throw new AuraHandledException('Invalid User ID provided.');
        }
        User targetUser = users[0];

        for (Integer i = 0; i < repeatCount; i++) {
            String mockEventKey = 'SIMULATION_' + System.now().getTime() + '_' + i;
            eventsToPublish.add(new SecurityAlert__e(
                EventKey__c = mockEventKey,
                Source__c = 'DEMO_SIMULATOR',
                PolicyCode__c = policyCode,
                Severity__c = 'HIGH', // 데모용 고정값
                UserId__c = targetUser.Id,
                UserName__c = targetUser.Name,
                ResourceType__c = 'Report', // 데모용
                ResourceName__c = 'Mass Export Simulation',
                Payload__c = '{"simulated": true, "attempt": ' + (i+1) + '}'
            ));
        }
        
        List<Database.SaveResult> results = EventBus.publish(eventsToPublish);
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                throw new AuraHandledException('Failed to publish simulation event: ' + sr.getErrors()[0].getMessage());
            }
        }
    }

    /**
     * @description 특정 보안 조치를 모의로 강제 실행합니다. 다양한 출처(Source)를 모의할 수 있습니다.
     * @param targetUserId 시뮬레이션 대상 유저 ID
     * @param actionName 실행할 액션 타입 (예: 'KILL_SESSION')
     * @param source 모의할 발생 출처 (예: 'TEAMS_INBOUND', 'LWC_DASHBOARD')
     */
    @AuraEnabled
    public static void simulateDirectAction(String targetUserId, String actionName, String source) {
        try {
            Map<String, Object> payload = new Map<String, Object>{
                'userId' => targetUserId,
                'source' => source
            };
            SecurityPrivilegeEscalator.executeAsSystem(actionName, JSON.serialize(payload));
        } catch (Exception e) {
            throw new AuraHandledException('Failed to simulate direct action: ' + e.getMessage());
        }
    }
}