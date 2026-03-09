/**
 * @Description 대상 유저의 로그인을 원천 차단하기 위해 계정을 동결(Freeze) 처리하는 액션.
 *              심각한 임계치(Critical) 위반 시 자동 방어 또는 관리자의 킬 세션 조치 등과 함께 사용됩니다.
 */
public with sharing class SecurityFreezeUserAction extends SecurityBaseAction {
    
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityFreezeUserAction.execute.NoUserId');
            return;
        }

        List<UserLogin> userLogins = [SELECT Id, UserId, IsFrozen FROM UserLogin WHERE UserId = :targetUserId LIMIT 1];
        if (!userLogins.isEmpty()) {
            if (!userLogins[0].IsFrozen) {
                userLogins[0].IsFrozen = true;
                update as system userLogins;
                SecuritySoarTrace.log('SecurityFreezeUserAction.execute.success', new Map<String, Object>{ 'UserId' => targetUserId });
                
                SecurityNotifyUtil.sendCompletionMessage(originalPayloadJson, 'SUCCESS', '✅ 사용자 계정이 성공적으로 동결 처리되었습니다.');
            } else {
                SecuritySoarTrace.log('SecurityFreezeUserAction.execute.already_frozen', new Map<String, Object>{ 'UserId' => targetUserId });
                
                SecurityNotifyUtil.sendCompletionMessage(originalPayloadJson, 'ALREADY_FROZEN', '⚠️ 해당 사용자는 이미 계정이 동결되어 있는 상태입니다.');
            }
        }
    }
}