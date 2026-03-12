/**
 * @Description 대상 유저의 프로필을 인가된 권한이 없는 '격리(Quarantine)' 또는 '읽기 전용' 프로필로
 *              강제 할당하여 추가적인 데이터 유출 및 수정을 방지하는 액션.
 */
global with sharing class SecurityQuarantineProfileAction extends SecurityBaseAction {
    
    global override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityQuarantineProfileAction.execute.NoUserId');
            return;
        }

        SecuritySoarTrace.log('SecurityQuarantineProfileAction.execute', new Map<String, Object>{ 'UserId' => targetUserId });

        // 가장 일반적인 'Read Only' 계열 프로필을 찾거나 커스텀 Quarantine 프로필 지정
        // 실무 환경에 맞춰 Name 바인딩 필요
        List<Profile> quarantineProfiles = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'Read Only' OR Name = 'Quarantine' 
            LIMIT 1
        ];
        
        if (!quarantineProfiles.isEmpty()) {
            List<User> targetUsers = [SELECT Id, ProfileId FROM User WHERE Id = :targetUserId LIMIT 1];
            if (!targetUsers.isEmpty()) {
                targetUsers[0].ProfileId = quarantineProfiles[0].Id;
                // DML. 시스템 컨텍스트로 업데이트
                update as system targetUsers;
                System.debug('🚨 SUCCESS: Moved User ' + targetUserId + ' to Quarantine/Read-Only Profile.');
            }
        } else {
            System.debug('🚨 WARN: No valid Quarantine/Read-Only Profile found in the org.');
            SecuritySoarTrace.log('SecurityQuarantineProfileAction.NoValidProfileFound');
        }
    }
}