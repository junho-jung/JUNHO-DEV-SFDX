/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-03      jh.jung           Created
*/

/**
 * @Description 특정 사용자의 활성 세션(AuthSession) 대량 삭제(Kill). 강제 로그아웃 유발.
 *
 * 호출 진입점: 인터셉터(SecurityAlertHandler), LWC, 인바운드(팀즈 링크 클릭) 등 다양한 경로에서 사용 가능.
 * @param payloadJson { "userId": "005...", "eventKey": "...", "policyCode": "..." }
 */
global without sharing class SecurityKillSessionAction extends SecurityBaseAction {

    global override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityKillSessionAction.execute.skip', new Map<String, Object>{ 'reason' => 'targetUserId is null' });
            return;
        }

        // 2. 해당 사용자의 활성 세션(AuthSession) 조회
        // IsCurrent = false 조건을 빼서 현재 세션을 포함한 모든 세션을 타겟팅함
        List<AuthSession> activeSessions = [
            SELECT Id, UsersId, SessionType, SourceIp
            FROM AuthSession
            WHERE UsersId = :targetUserId
            AND SessionType != 'TempUIFrontEnd' // 관리용 임시 세션 제외 가능
        ];

        if (activeSessions.isEmpty()) {
            SecuritySoarTrace.log('SecurityKillSessionAction.execute.no_sessions', new Map<String, Object>{ 'targetUserId' => targetUserId });
            
            // 삭제할 세션이 없는 경우에도 알림 발송
            SecurityNotifyUtil.sendCompletionMessage(originalPayloadJson, 'NO_SESSIONS', 'ℹ️ 해당 사용자의 활성화된 세션이 존재하지 않습니다.');
            return;
        }

        // 3. 세션 레코드 삭제 (DML 삭제 시 즉시 로그아웃 처리됨)
        // Database.delete를 사용하여 부분 성공 허용하거나 에러 핸들링
        Database.DeleteResult[] results = Database.delete(activeSessions, false);
        
        Integer successCount = 0;
        for (Database.DeleteResult dr : results) {
            if (dr.isSuccess()) successCount++;
        }

        SecuritySoarTrace.log('SecurityKillSessionAction.execute.deleted', new Map<String, Object>{
            'targetUserId' => targetUserId,
            'totalSessions' => activeSessions.size(),
            'successCount' => successCount
        });

        SecurityNotifyUtil.sendCompletionMessage(originalPayloadJson, 'SUCCESS', '✅ 총 ' + successCount + '개의 세션이 정상적으로 강제 해제되었습니다.');
    }
}