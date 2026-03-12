/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-03      jh.jung           Created
*/

global class SecurityCreateCaseAction extends SecurityBaseAction {
    global override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (!Schema.sObjectType.Case.isCreateable()) {
            throw new SecurityException('No create access to Case.');
        }

        String policyCode = String.valueOf(payloadMap.get('policyCode'));
        String severity = String.valueOf(payloadMap.get('severity'));
        String userName = String.valueOf(payloadMap.get('userName'));
        String eventKey = String.valueOf(payloadMap.get('eventKey'));

        Case c = new Case();
        c.Subject = '[Security] ' + policyCode + ' / ' + severity + ' / ' + userName;
        c.Description = originalPayloadJson;
        c.Origin = 'Security';
        if (String.isNotBlank(eventKey)) c.SecurityEventKey__c = eventKey;

        SObjectAccessDecision stripped = Security.stripInaccessible(AccessType.CREATABLE, new List<SObject>{ c });
        List<SObject> records = stripped.getRecords();
        if (records.isEmpty()) return;

        // Idempotent create using external id
        upsert (Case) records[0] SecurityEventKey__c;
    }
}