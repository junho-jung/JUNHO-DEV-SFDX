/**
* @Author            : jh.jung
* @Description 		 : 기존 사내망 프레임워크(Interface__c)를 통해 Teams 알림을 전송하는 브릿지 전용 레거시 액션 클래스입니다.
*                      SOAR 순수 패키징 관점에서는 제외되며, 고객사가 기존 레거시와 연동할 때 플러그인 형태로 사용합니다.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-03-11      jh.jung           Created - Tier 2 Legacy Bridge Extension
*/
public class SecurityNotifyTeamsLegacyAction extends SecurityBaseAction {
    
    // 이 클래스는 순수 웹훅(BaseWebhook) 구조를 쓰지 않고 가장 범용적인 BaseAction을 상속받습니다.
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        
        // 1. 순수 HTTP 콜아웃 로직 대신, 사내 레거시 브릿지로 데이터를 다이렉트로 토스합니다.
        // 2. 브릿지를 타고 넘어가면, 'SecurityIntegration__mdt' 설정에 따라 'InterfaceTeamsNotifier'가 실행됩니다.
        SecurityInterfaceBridge.callForAction('NOTIFY_TEAMS', originalPayloadJson);
        
        SecuritySoarTrace.log('SecurityNotifyTeamsLegacyAction.doExecute', new Map<String, Object>{
            'status' => 'Routed to Legacy Bridge',
            'actionType' => 'NOTIFY_TEAMS_LEGACY'
        });
    }
}