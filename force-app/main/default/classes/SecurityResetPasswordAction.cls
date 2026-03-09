/**
 * @Description 대상 유저의 비밀번호를 즉시 강제 초기화(Reset)하고
 *              초기화 메일을 시스템적으로 발송하도록 하는 액션 (System.resetPassword 호출).
 */
public with sharing class SecurityResetPasswordAction extends SecurityBaseAction {
    
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityResetPasswordAction.execute.NoUserId');
            return;
        }

        SecuritySoarTrace.log('SecurityResetPasswordAction.execute', new Map<String, Object>{ 'UserId' => targetUserId });

        // 시스템 권한을 활용하여 비밀번호를 즉각 리셋 (두 번째 파라미터가 true 이면 안내 이메일 발송)
        System.resetPassword(targetUserId, true);
        System.debug('🚨 SUCCESS: Password reset initiated for User ' + targetUserId);
    }
}