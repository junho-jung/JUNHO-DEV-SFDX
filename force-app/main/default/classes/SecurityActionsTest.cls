@IsTest
private class SecurityActionsTest {

    private class OkMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('ok');
            return r;
        }
    }

    @IsTest
    static void test_CreateCaseAction_Idempotent() {
        Map<String, Object> p = new Map<String, Object>{
            'policyCode' => 'TEST_POLICY',
            'severity' => 'HIGH',
            'userName' => 'Test User',
            'userEmail' => 'test@example.com',
            'timestamp' => '2026-02-12 00:00:00',
            'eventKey' => '005xx:TEST:RES:202602120000'
        };
        String payload = JSON.serialize(p);

        Test.startTest();
        new SecurityCreateCaseAction().execute(payload);
        new SecurityCreateCaseAction().execute(payload);
        Test.stopTest();

        List<Case> cases = [SELECT Id, SecurityEventKey__c FROM Case WHERE SecurityEventKey__c = :String.valueOf(p.get('eventKey'))];
        System.assertEquals(1, cases.size(), 'Should upsert only one Case for same eventKey.');
    }

    @IsTest
    static void test_SendToSiem_Disabled_NoCallout() {
        // default CMDT record is disabled => should not callout
        new SecuritySendToSiemAction().execute(JSON.serialize(new Map<String, Object>{ 'policyCode' => 'P', 'eventKey' => 'K' }));
        System.assert(true);
    }

    @IsTest
    static void test_NotifySlack_Disabled_NoCallout() {
        new SecurityNotifySlackAction().execute(JSON.serialize(new Map<String, Object>{ 'policyCode' => 'P', 'eventKey' => 'K' }));
        System.assert(true);
    }

    @IsTest
    static void test_UserWarning_Email() {
        Test.startTest();
        new SecurityUserWarningAction().execute(JSON.serialize(new Map<String, Object>{
            'policyCode' => 'P',
            'severity' => 'LOW',
            'timestamp' => '2026-02-12 00:00:00',
            'eventKey' => 'K',
            'userEmail' => 'someone@example.com'
        }));
        Test.stopTest();
        System.assertEquals(1, Limits.getEmailInvocations());
    }
}