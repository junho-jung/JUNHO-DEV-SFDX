/**
 * @Description 팀즈 알림 발송용 보안 액션
 *              SecurityActionFactory를 통해 ASYNC 모드로 생성되어
 *              SecurityActionExecutor 안에서 단일 Queueable 잡으로 실행됨.
 */
public class SecurityNotifyTeamsAction extends SecurityBaseWebhookAction {
    protected override String getActionType() {
        return 'NOTIFY_TEAMS';
    }

    protected override String buildRequestBody(Map<String, Object> payloadMap, String originalPayloadJson) {
        // 공통 Payload Builder를 통해 화려한 Teams Adaptive Card JSON을 생성하여 반환합니다.
        String cardJson = SecurityTeamsPayloadBuilder.buildPayload(originalPayloadJson);
        return String.isNotBlank(cardJson) ? cardJson : originalPayloadJson;
    }
}