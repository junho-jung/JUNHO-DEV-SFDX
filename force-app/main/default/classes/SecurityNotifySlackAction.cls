/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/

global class SecurityNotifySlackAction extends SecurityBaseWebhookAction {
    global override String getActionType() {
        return 'NOTIFY_SLACK';
    }
}