/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/

public class SecurityNotifySlackAction extends SecurityBaseWebhookAction {
    protected override String getActionType() {
        return 'NOTIFY_SLACK';
    }
}