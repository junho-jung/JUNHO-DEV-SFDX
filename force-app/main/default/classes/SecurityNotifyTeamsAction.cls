/**
 * @Description 팀즈 알림 발송용 보안 액션
 *              SecurityActionFactory를 통해 ASYNC 모드로 생성되어
 *              SecurityActionExecutor 안에서 단일 Queueable 잡으로 실행됨.
 */
public class SecurityNotifyTeamsAction extends SecurityBaseAction {
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        // Bridge를 통해 ActionType → SecurityIntegration__c → InterfaceConfig__mdt 경로로 전송
        SecurityInterfaceBridge.callForAction('NOTIFY_TEAMS', originalPayloadJson);
    }
}