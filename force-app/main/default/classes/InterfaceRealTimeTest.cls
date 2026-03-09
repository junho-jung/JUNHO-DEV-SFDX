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
private class InterfaceRealTimeTest {

    // =================================================================
    // 1. 테스트용 가짜 구현체 (Stub)
    // =================================================================
    private class TestRealTimeImpl extends InterfaceRealTime {

        // 에러 테스트를 위한 스위치
        public Boolean shouldFailBefore = false;

        public TestRealTimeImpl() {
            super();
            // 응답을 Map으로 파싱하겠다고 설정
            this.setResponseType(null);
        }

        public override Object before() {
            // 에러 시뮬레이션
            if (shouldFailBefore) {
                throw new CalloutException('Before Hook Error Triggered');
            }
            // 정상 요청 데이터
            return new Map<String, String>{'testKey' => 'testValue'};
        }

        public override void after(InterfaceHandler.ReturnCls rc) {
            System.debug('After Hook Executed');
        }
    }

    // =================================================================
    // 2. HTTP Callout Mock
    // =================================================================
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

    // =================================================================
    // 3. Helper: 가짜 메타데이터 생성기
    // =================================================================
    private static InterfaceConfig__mdt createMockConfig() {
        // 읽기 전용인 __mdt 객체를 만들기 위해 JSON 역직렬화 기법 사용
        // 주의: 실제 필드 API Name과 정확히 일치해야 함
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => 'TEST_REALTIME',
            'NamedCredential__c' => null,     // Named Credential
            'ResourcePath__c' => '/api/test',     // Path
            'Method__c' => 'POST',                // Method
            'Timeout__c' => 12000,                // Timeout (Decimal -> Integer 자동변환됨)
            'isActive__c' => true                 // Active
        };
        return (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);
    }

    // =================================================================
    // 4. Test Cases
    // =================================================================

    @IsTest
    static void testExecuteSuccess() {
        // Given
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(200, '{"result":"success"}'));

        // Mock Config 생성
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => 'TEST_REALTIME',
            'Method__c' => 'POST',
            'ResourcePath__c' => '/test'
        };
        InterfaceConfig__mdt config = (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);

        // 구현체 생성 및 설정 주입
        TestRealTimeImpl impl = new TestRealTimeImpl();
        impl.configure(config);

        // 헤더 추가 테스트
        impl.addHeader('Authorization', 'Bearer Test');

        // When
        Test.startTest();
        InterfaceHandler.ReturnCls rc = (InterfaceHandler.ReturnCls) impl.call();
        Test.stopTest();

        // Then
        // 1. 기본 객체 확인
        System.assertNotEquals(null, rc, 'Result should not be null');
        System.assertEquals(InterfaceHandler.SUCCESS, rc.log.Status__c, 'Status should be SUCCESS');

        // 2. 디버깅: Body가 잘 들어왔는지 확인
        System.debug('Response Body: ' + rc.responseBody);
        System.assertNotEquals(null, rc.responseBody, 'Response Body should not be null');

        System.debug(rc.log);
        // 3. 디버깅: 파싱이 잘 되었는지 확인 (여기서 실패한다면 InterfaceHandler 문제)
        System.assertNotEquals(null, rc.responseObject, 'Response Object Parsing Failed. Check InterfaceHandler logic.');

        // 4. 안전하게 캐스팅 후 검증
        Map<String, Object> resMap = (Map<String, Object>) rc.responseObject;
        System.assertEquals('success', resMap.get('result'));
    }

    @IsTest
    static void testBeforeException() {
        // Given
        TestRealTimeImpl impl = new TestRealTimeImpl();
        impl.configure(createMockConfig());

        // ★ 에러 강제 유발 설정
        impl.shouldFailBefore = true;

        // When
        Test.startTest();
        // before에서 에러가 나면 null을 리턴하도록 설계했음
        Object result = impl.call();
        Test.stopTest();

        // Then
        // 1. 리턴값 검증
        System.assertEquals(null, result, 'Should return null on exception');

        // 2. 에러 로그 적재 확인
        // ReturnCls가 null이더라도 DB에는 에러 로그가 남아야 함 (INF.error 호출)
        List<InterfaceLog__c> logs = [SELECT Id, Status__c, ErrorMessage__c FROM InterfaceLog__c];
        System.assertEquals(1, logs.size(), 'Error log should be created');
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, logs[0].Status__c); // INF.error()는 RESPONSE_ERROR 등을 세팅함
        System.assert(logs[0].ErrorMessage__c.contains('Before Hook Error'), 'Error message match');
    }

    @IsTest
    static void testHttpError() {
        // Given
        // 500 에러를 리턴하는 Mock 설정
        Test.setMock(HttpCalloutMock.class, new MockHttpResponse(500, '{"error":"Internal Server Error"}'));

        TestRealTimeImpl impl = new TestRealTimeImpl();
        impl.configure(createMockConfig());

        // When
        Test.startTest();
        InterfaceHandler.ReturnCls rc = (InterfaceHandler.ReturnCls) impl.call();
        Test.stopTest();

        // Then
        System.assertNotEquals(null, rc, 'Return object should exist even on fail');
        System.assertEquals(InterfaceHandler.RESPONSE_ERROR, rc.log.Status__c, 'Status should be RESPONSE_ERROR');
        System.assert(rc.log.ErrorMessage__c.contains('Internal Server Error'), 'Error body match');

        // DB 확인
        List<InterfaceLog__c> logs = [SELECT Id, Status__c FROM InterfaceLog__c];
        System.assertEquals(1, logs.size());
    }

    @IsTest
    static void testConfigurationMissing() {
        // Given
        TestRealTimeImpl impl = new TestRealTimeImpl();
        // configure()를 호출하지 않음 -> Service 초기화 안 됨

        // When
        Test.startTest();
        Object result = impl.call();
        Test.stopTest();

        // Then
        // execute -> sendRequest -> Service.send -> "Not Configured" 예외 -> handleException -> return null
        System.assertEquals(null, result, 'Should return null on config error');

        // 시스템 에러 로그 확인
        List<InterfaceLog__c> logs = [SELECT Id, Status__c, ErrorMessage__c FROM InterfaceLog__c];
        System.assertEquals(1, logs.size());
        System.assertEquals(InterfaceHandler.SYSTEM_ERROR, logs[0].Status__c);
        System.debug(logs[0].ErrorMessage__c); // "setup() first" 메시지 확인용
    }
}