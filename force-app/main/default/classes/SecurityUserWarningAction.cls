/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/

global class SecurityUserWarningAction extends SecurityBaseAction {
    global override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        String userEmail = String.valueOf(payloadMap.get('userEmail'));
        if (String.isBlank(userEmail)) return;

        String policyCode = String.valueOf(payloadMap.get('policyCode'));
        String severity = String.valueOf(payloadMap.get('severity'));
        String timestamp = String.valueOf(payloadMap.get('timestamp'));
        String eventKey = String.valueOf(payloadMap.get('eventKey'));

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ userEmail });
        mail.setSubject('[Security Alert] ' + policyCode + ' / ' + severity);
        mail.setPlainTextBody(
            'A security alert was detected in your Salesforce org.' +
            '\n\n- policy: ' + policyCode +
            '\n- severity: ' + severity +
            '\n- time: ' + timestamp +
            '\n- eventKey: ' + eventKey +
            '\n\nIf you believe this is not expected, contact your admin/security team.'
        );
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
    }
}