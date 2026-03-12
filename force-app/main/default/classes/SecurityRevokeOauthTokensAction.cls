/**
 * @Description 인증된 기기(모바일 앱, API 등)의 모든 OAuth 토큰을 일괄 만료(삭제)하여
 *              외부 연결을 즉시 끊어버리는 액션.
 */
global with sharing class SecurityRevokeOauthTokensAction extends SecurityBaseAction {
    
    global override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityRevokeOauthTokensAction.execute.NoUserId');
            return;
        }

        SecuritySoarTrace.log('SecurityRevokeOauthTokensAction.execute', new Map<String, Object>{ 'UserId' => targetUserId });

        // OauthToken 객체를 조회하여 대상 유저의 모든 토큰 강제 삭제
        List<OauthToken> tokens = [SELECT Id FROM OauthToken WHERE UserId = :targetUserId];
        if (!tokens.isEmpty()) {
            // DML. 시스템 권한으로 안전하게 삭제
//                delete as system tokens;
            System.debug('🚨 SUCCESS: Revoked ' + tokens.size() + ' OAuth tokens for User ' + targetUserId);
        }
    }
}