/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/

public class SecurityNotifySlackAction extends SecurityBaseAction {
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        // Bridge를 통해 ActionType → SecurityIntegration__c → InterfaceConfig__mdt 경로로 전송
        SecurityInterfaceBridge.callForAction('NOTIFY_SLACK', originalPayloadJson);
    }
}