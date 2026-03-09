/**
 * @Description 보안 액션 완료 후 팀즈 등의 공통 알림(Callback Message)을 발송하는 유틸리티 클래스
 */
public with sharing class SecurityNotifyUtil {

    /**
     * @description 지정된 페이로드와 상태 메시지를 병합하여 비동기 알림 생성 (주로 NOTIFY_TEAMS 연결)
     * @param originalPayloadJson 기존 액션에 들어왔던 Payload 내용
     * @param status 'SUCCESS' 또는 'ALREADY_FROZEN' 등 결과 상태 명칭
     * @param message 사용자에게 보여질 실제 안내 메시지
     */
    public static void sendCompletionMessage(String originalPayloadJson, String status, String message) {
        try {
            if (String.isBlank(originalPayloadJson)) return;
            
            Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(originalPayloadJson);
            
            // 인바운드(Teams)에서 요청한 경우에만 팀즈 완료 알림 비동기 발송
            String source = (String) payload.get('source');
            if (String.isBlank(source) || source != SecurityTypes.SOURCE_TEAMS_INBOUND) {
                return;
            }

            payload.put('actionStatus', status);
            payload.put('actionMessage', message);
            String newPayloadJson = JSON.serialize(payload);

            SecurityTypes.ActionDescriptor descr = SecurityActionFactory.getAction('NOTIFY_TEAMS');
            if (descr != null && descr.action != null) {
                SecurityActionExecutor.execute(descr.action, newPayloadJson, descr.mode);
                SecuritySoarTrace.log('SecurityNotifyUtil.sendCompletionMessage', new Map<String, Object>{
                    'status' => 'Notification Enqueued',
                    'actionStatus' => status
                });
            }
        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityNotifyUtil.error', new Map<String, Object>{
                'errorMsg' => e.getMessage()
            });
        }
    }
}