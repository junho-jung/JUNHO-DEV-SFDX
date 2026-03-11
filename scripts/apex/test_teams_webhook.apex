/**
* @description 이 스크립트는 SOAR 시스템의 Teams 동적 웹훅 발송을 테스트하기 위해
*              임의의 SecurityAlert__e 이벤트를 강제로 발생시킵니다.
* @usage Execute Anonymous (sf apex run -f scripts/apex/test_teams_webhook.apex)
*/

// 1. Medium 위협 데모: 관리자에게 액션(버튼) 권유만 함
SecurityAlert__e alertMedium = new SecurityAlert__e(
    EventKey__c     = 'DEMO_MED_' + System.now().format('HHmmss'),
    Source__c       = 'ApiEvent',
    PolicyCode__c   = 'NIGHT_API_HEIST',
    Severity__c     = 'MEDIUM',
    ActionType__c   = 'NOTIFY_TEAMS', // 미디엄: 알림만 발송
    UserId__c       = UserInfo.getUserId(),
    UserName__c     = UserInfo.getName(),
    ResourceName__c = 'Contact',
    ResourceType__c = 'ApiEvent',
    Payload__c      = JSON.serialize(new Map<String, Object>{
        'userId' => UserInfo.getUserId(),
        'userName' => UserInfo.getName(),
        'profile' => 'System Administrator',
        'policyCode' => 'NIGHT_API_HEIST',
        'severity' => 'MEDIUM',
        'actionName' => 'Query',
        'resourceType' => 'ApiEvent',
        'query' => 'SELECT Id, Name, Email, Phone FROM Contact LIMIT 100',
        'rows' => 100,
        // Handler에서 메타데이터 설정에 따라 추가적으로 들어가는 값 모방
        'actionButtons' => 'FREEZE_USER;KILL_SESSION' 
    })
);

// 2. Critical 위협 데모: 자동 조치 수행 후 결과만 통지함 (버튼 없음)
SecurityAlert__e alertCritical = new SecurityAlert__e(
    EventKey__c     = 'DEMO_CRI_' + System.now().format('HHmmss'),
    Source__c       = 'ApiEvent',
    PolicyCode__c   = 'NIGHT_API_HEIST',
    Severity__c     = 'CRITICAL',
    // 자동화 조치인 FETCH_FREEZE_KILL 이 선행되었고 체인 마지막에 알림이 간다고 가정
    ActionType__c   = 'NOTIFY_TEAMS', 
    UserId__c       = UserInfo.getUserId(),
    UserName__c     = UserInfo.getName(),
    ResourceName__c = 'Contact',
    ResourceType__c = 'ApiEvent',
    Payload__c      = JSON.serialize(new Map<String, Object>{
        'userId' => UserInfo.getUserId(),
        'userName' => UserInfo.getName(),
        'profile' => 'System Administrator',
        'policyCode' => 'NIGHT_API_HEIST',
        'severity' => 'CRITICAL',
        'actionName' => 'Query',
        'resourceType' => 'ApiEvent',
        'query' => 'SELECT Id, Email, SSN__c FROM Contact LIMIT 50000',
        'rows' => 10000,
        // 이미 자동 차단을 때렸기 때문에 UI 액션 생략
        'actionStatus' => 'SUCCESS', 
        'alertTitle' => '보안 자동 방어 발동 (계정 동결 완료)',
        'actionMessage' => 'Critical 위협이 감지되어 SOAR 엔진이 즉시 대상 계정 세션을 종료하고 강제 동결(Freeze) 처리했습니다.'
    })
);

// 3. Low 위협 데모: 여러 개의 조치 방안(버튼 다수)을 모아서 권고함
SecurityAlert__e alertLow = new SecurityAlert__e(
    EventKey__c     = 'DEMO_LOW_' + System.now().format('HHmmss'),
    Source__c       = 'ApiEvent',
    PolicyCode__c   = 'VIP_DATA_ACCESS',
    Severity__c     = 'LOW',
    ActionType__c   = 'NOTIFY_TEAMS', 
    UserId__c       = UserInfo.getUserId(),
    UserName__c     = UserInfo.getName(),
    ResourceName__c = 'Contact',
    ResourceType__c = 'ApiEvent',
    Payload__c      = JSON.serialize(new Map<String, Object>{
        'userId' => UserInfo.getUserId(),
        'userName' => UserInfo.getName(),
        'profile' => 'System Administrator',
        'policyCode' => 'VIP_DATA_ACCESS',
        'severity' => 'LOW',
        'actionName' => 'Query',
        'resourceType' => 'ApiEvent',
        'query' => 'SELECT Id, Name FROM Lead WHERE Title LIKE \'%CEO%\'',
        'rows' => 5,
        // 다양한 액션 버튼 동적 렌더링 테스트
        'actionButtons' => 'FREEZE_USER;KILL_SESSION;REVOKE_TOKEN;REQUIRE_MFA;CREATE_CASE;RESTRICT_PERMISSION' 
    })
);

// 시차를 두고 시스템 발송 시뮬레이션
EventBus.publish(alertLow);
System.debug('✅ [DEMO 1] Low Level - Multi-Action Buttons Request sent via Teams Webhook');

Long startTime1 = System.currentTimeMillis();
while (System.currentTimeMillis() - startTime1 < 1000) {}

EventBus.publish(alertMedium);
System.debug('✅ [DEMO 2] Medium Level - Standard Setup sent via Teams Webhook');

Long startTime2 = System.currentTimeMillis();
while (System.currentTimeMillis() - startTime2 < 1000) {}

EventBus.publish(alertCritical);
System.debug('✅ [DEMO 3] Critical Level - Auto-Action Consequence sent via Teams Webhook');
