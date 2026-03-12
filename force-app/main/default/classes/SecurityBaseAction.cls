/**
 * @Description Security 공통 Action 부모 클래스.
 *              반복되는 Payload 파싱, 사용자 ID 추출, 공통 로깅, 예외 처리를 추상화하여 제공합니다.
 */
global abstract class SecurityBaseAction implements ISecurityAction {
    
    global void execute(String payloadJson) {
        String actionName = String.valueOf(this).substringBefore(':');
        
        SecuritySoarTrace.log(actionName + '.execute.start', new Map<String, Object>{ 'payload' => payloadJson });
        if (String.isBlank(payloadJson)) return;

        Map<String, Object> payloadMap;
        try {
            payloadMap = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
        } catch (Exception e) {
            SecuritySoarTrace.log(actionName + '.execute.ParseError', payloadJson);
            throw new AuraHandledException('Payload Parsing Error');
        }

        // 대상 식별자 일반화 추출 (userId vs UserId)
        String targetUserId = (String) payloadMap.get('userId');
        if (String.isBlank(targetUserId)) {
            targetUserId = (String) payloadMap.get('UserId');
        }

        try {
            doExecute(payloadMap, targetUserId, payloadJson);
        } catch (Exception e) {
            SecuritySoarTrace.log(actionName + '.execute.Error', new Map<String, Object>{ 'ErrorMessage' => e.getMessage() });
            throw e; 
        }
    }

    /**
     * @Description 개별 Action에서 실제 수행할 비즈니스 로직.
     * @param payloadMap 파싱된 페이로드 맵
     * @param targetUserId 추출된 대상 User Id (없는 경우 null/blank)
     * @param originalPayloadJson 원본 JSON 문자열
     */
    global abstract void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson);
}