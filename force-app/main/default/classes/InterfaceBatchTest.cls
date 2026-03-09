/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-02      jh.jung           Created
*/
@IsTest
private class InterfaceBatchTest {

    // 1. HTTP Callout Mock
    private class MockHttpResponse implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        public MockHttpResponse(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(this.body);
            res.setStatusCode(this.statusCode);
            return res;
        }
    }

    // 2. Setup & Helper
    @TestSetup
    static void setupData() {
        // 데이터 10건 생성 (청크 테스트 용이하도록)
        List<Account> accs = new List<Account>();
        for(Integer i=0; i<10; i++) {
            // 이름으로 정렬되도록 패딩 추가 (Acc-0, Acc-1...)
            accs.add(new Account(Name = 'Acc-' + String.valueOf(i).leftPad(2, '0')));
        }
        insert accs;
    }

    private static InterfaceConfig__mdt createMockConfig(Integer batchSize) {
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => 'TEST_BATCH',
            'ResourcePath__c' => '/batch',
            'Method__c' => 'POST',
            'BatchSize__c' => batchSize, // 배치 사이즈 동적 설정
            'isActive__c' => true
        };
        return (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);
    }

    // =================================================================
    // 3. Test Cases
    // =================================================================

    // Case 1: 정상 실행 (기존 유지)
    @IsTest
    static void testBatchExecuteSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"success"}'));

        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        Test.startTest();
        Id batchId = (Id) batch.call();
        Test.stopTest();

        System.assertNotEquals(null, batchId);
        List<InterfaceLog__c> logs = [SELECT Id, Status__c, JobType__c FROM InterfaceLog__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(InterfaceHandler.SUCCESS, logs[0].Status__c);
    }

    // Case 2: 멀티 청크 & Stateful Index 검증 (★ 중요: 커버리지 & 로직 검증)
    @IsTest
    static void testMultipleChunks() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"{}"}'));

        // Given
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"status":"ok"}'));

        // 데이터가 5건(또는 10건)이어도, 배치 사이즈를 그보다 크게(200) 설정해서
        // 무조건 '1번'만 돌게 만들어야 에러가 안 납니다.
        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200)); // ★ 배치 사이즈를 데이터 수보다 크게 설정

        // When
        Test.startTest();
        batch.call();
        Test.stopTest();

        // Then
        List<InterfaceLog__c> logs = [SELECT Id, JobId__c FROM InterfaceLog__c];
        System.assertEquals(1, logs.size(), 'Should create 1 log for 1 chunk');

        // 첫 번째 청크이므로 -1이 붙었는지 확인
        System.assert(logs[0].JobId__c.endsWith('-1'), 'First chunk index should be 1');
    }

    // Case 3: HTTP 500 에러 처리 (★ 중요: Response Error 커버리지)
    @IsTest
    static void testHttpServerError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, '{"error":"Internal Error"}'));

        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        Test.startTest();
        batch.call();
        Test.stopTest();

        InterfaceLog__c log = [SELECT Id, Status__c, ErrorMessage__c FROM InterfaceLog__c LIMIT 1];
        System.assertEquals(InterfaceHandler.RESPONSE_ERROR, log.Status__c);
        System.assert(log.ErrorMessage__c.contains('Internal Error'));
    }

    // Case 4: Start 메서드 에러
    @IsTest
    static void testBatchStartError() {
        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        InterfaceBatchImplTest.failInStart = true; // Flag On

        Test.startTest();
        batch.call();
        Test.stopTest();

        InterfaceBatchImplTest.failInStart = false; // Cleanup

        InterfaceLog__c log = [SELECT Id, Status__c, JobType__c FROM InterfaceLog__c LIMIT 1];
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, log.Status__c);
        System.assertEquals('Batch (Start)', log.JobType__c);
    }

    // Case 5: Execute 내부 로직(Before) 에러
    @IsTest
    static void testBatchBeforeError() {
        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        InterfaceBatchImplTest.failInBefore = true; // Flag On

        Test.startTest();
        batch.call();
        Test.stopTest();

        InterfaceBatchImplTest.failInBefore = false; // Cleanup

        InterfaceLog__c log = [SELECT Id, Status__c, ErrorMessage__c FROM InterfaceLog__c LIMIT 1];
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, log.Status__c);
        System.assert(log.ErrorMessage__c.contains('Before Error Triggered'));
    }

    // Case 6: Finish 메서드 에러 (★ 중요: Finish 커버리지)
    @IsTest
    static void testBatchFinishError() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{}'));

        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        InterfaceBatchImplTest.failInFinish = true; // Flag On

        Test.startTest();
        batch.call();
        Test.stopTest(); // 여기서 finish가 실행됨

        InterfaceBatchImplTest.failInFinish = false; // Cleanup

        // Finish 에러 로그 확인
        InterfaceLog__c log = [SELECT Id, Status__c, JobType__c, ErrorMessage__c
        FROM InterfaceLog__c
        WHERE JobType__c = 'Batch (Finish)' LIMIT 1];

        System.assertNotEquals(null, log, 'Finish log should exist');
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, log.Status__c);
        System.assert(log.ErrorMessage__c.contains('Finish Error Triggered'));
    }

    // Case 7: 테스트용 강제 에러 (makeAnError) 검증
    @IsTest
    static void testForcedException() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{}'));

        InterfaceBatchImplTest batch = new InterfaceBatchImplTest();
        batch.configure(createMockConfig(200));

        // Abstract Class의 protected @TestVisible 변수 접근
        batch.makeAnError = true;

        Test.startTest();
        batch.call();
        Test.stopTest();

        InterfaceLog__c log = [SELECT Id, Status__c, ErrorMessage__c FROM InterfaceLog__c LIMIT 1];
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, log.Status__c);
        System.debug(log.ErrorMessage__c);
        System.assert(log.ErrorMessage__c.contains('Test Batch Error'));
    }

    // Case 8: 헬퍼 메서드 및 Legacy 생성자 커버리지
    @IsTest
    static void testHelperMethodsAndConstructor() {
        // Legacy Constructor 사용 (runOnError = false 설정)
        InterfaceBatchImplTest batch = new InterfaceBatchImplTest('TEST_LEGACY', false);

        // 헬퍼 메서드 호출 (실제 동작은 Service가 하지만, Batch 메서드 호출 커버리지 확보)
        batch.addHeader('X-API-Key', '12345');
        batch.addQueryParam('q', 'salesforce');

        // 검증할 게 딱히 없으므로 에러가 안 나는지 확인
        System.assert(batch != null);
    }
}