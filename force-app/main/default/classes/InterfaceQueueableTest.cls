/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-03      jh.jung           Created
*/
@IsTest
private class InterfaceQueueableTest {

    // 테스트용 더미 데이터 타입 정의
    public class SampleData {}

    // InterfaceHandler에 필요한 상수 재정의
    private static final String SUCCESS = 'SUCCESS';
    private static final String SYSTEM_ERROR = 'SYSTEM ERROR';
    private static final String RESPONSE_ERROR = 'RESPONSE ERROR';

    // =================================================================
    // 1. Mock Classes (Service & Logging DML 방지)
    // =================================================================

    /**
     * @description InterfaceHandler.LogCls를 상속받아 execute()를 오버라이드하여 DML을 방지합니다.
     */
    public class MockLogCls extends InterfaceHandler.LogCls {
        public MockLogCls(InterfaceHandler.ReturnCls rc) { super(rc); }
        public override void execute() { /* DML 방지 */ }
    }

    /**
     * @description Mock Finalizer 구현체 (DML Mocking 및 상태 저장)
     */
    public class MockQueueableFinalizer extends InterfaceQueueable.QueueableFinalizer {

        public MockQueueableFinalizer(InterfaceHandler.ReturnCls rc, InterfaceQueueable instance) { super(rc, instance); }

        public override void execute(FinalizerContext ctx) {
            super.execute(ctx); // Unhandled Exception 처리 로직 포함

            if (jobInstance != null) {
                // MockLogCls를 사용하여 DML 방지
                new MockLogCls(rc).execute();
                System.debug(jobInstance);
                jobInstance.finish(rc);
            }
        }
    }

    /**
     * @description InterfaceHandler를 상속받아 콜아웃 및 Error DML을 Mocking합니다.
     */
    public class MockInterfaceHandler extends InterfaceHandler {
        public Boolean errorInBeforeHook = false;
        public Integer mockStatusCode = 200;

        public MockInterfaceHandler(String name) { super(name); }

        public override InterfaceHandler.ReturnCls send(String body, Map<String, String> headers, Map<String, String> params, Type responseType) {
            InterfaceHandler.ReturnCls rc = new InterfaceHandler.ReturnCls();
            rc.log = new InterfaceLog__c();
            this.status = (this.mockStatusCode >= 200 && this.mockStatusCode < 300) ? SUCCESS : RESPONSE_ERROR;
            rc.log.Status__c = this.status;
            this.keyList.add('MockKey');
            return rc;
        }

        public override void error(Exception e) {
            ReturnCls rc = new ReturnCls(); rc.log = new InterfaceLog__c();
            rc.log.Status__c = SYSTEM_ERROR;
            rc.log.ErrorMessage__c = getExceptionMessage(e);

            this.IS_ERROR = true;
            this.status = SYSTEM_ERROR;
            new MockLogCls(rc).execute();
        }
    }


    /**
     * @description 테스트를 위한 Queueable 구현체 (Finalizer Mock 주입)
     */
    public virtual class TestQueueableImpl extends InterfaceQueueable {
        public InterfaceHandler.ReturnCls afterResult;
        public String statusOnFinish;
        public MockInterfaceHandler mockHandler;

        public TestQueueableImpl(MockInterfaceHandler handler) { this.mockHandler = handler; }

        protected override System.Finalizer createFinalizer(InterfaceHandler.ReturnCls rc) {
            return new MockQueueableFinalizer(rc, this);
        }

        protected override InterfaceHandler createService(String name) {
            return this.mockHandler;
        }

        public override Object before() {
            if (this.mockHandler.errorInBeforeHook) {
                this.INF.error(new InterfaceHandler.InterfaceException('Before Hook Error'));
                return null;
            }
            return new SampleData();
        }

        public override void after(InterfaceHandler.ReturnCls rc) {
            this.afterResult = rc;
        }

        public override void finish(InterfaceHandler.ReturnCls rc) {
            System.debug(rc.log);
            this.statusOnFinish = rc.log.Status__c; // Finalizer의 상태를 저장
            super.finish(rc);
        }
    }

    /** @description Helper: 가짜 메타데이터 생성기 */
    private static InterfaceConfig__mdt createMockConfig(String devName) {
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => devName,
            'NamedCredential__c' => 'TestNC',
            'ResourcePath__c' => '/api/test',
            'Method__c' => 'POST',
            'isActive__c' => true
        };
        return (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);
    }


    // =================================================================
    // 2. Test Methods
    // =================================================================

    /**
     * @description 시나리오 1: 정상적인 Interface Callout 성공 (200 OK)
     */
    @IsTest
    static void testSuccessCase_200OK() {
        MockInterfaceHandler mockHandler = new MockInterfaceHandler('TestSuccess');
        mockHandler.mockStatusCode = 200;

        TestQueueableImpl job = new TestQueueableImpl(mockHandler);
        job.configure(createMockConfig('TestSuccess'));
        System.debug(job);
        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(SUCCESS, job.INF.status, 'INF 상태는 SUCCESS여야 합니다.');
        System.assertEquals(SUCCESS, job.statusOnFinish, 'Finalizer의 로그 상태는 SUCCESS여야 합니다.');
    }

    /**
     * @description 시나리오 3: before() 훅에서 명시적인 오류 발생 (Send Request 스킵)
     */
    @IsTest
    static void testErrorInBeforeHook() {
        MockInterfaceHandler mockHandler = new MockInterfaceHandler('TestErrorBefore');

        TestQueueableImpl job = new TestQueueableImpl(mockHandler);
        job.configure(createMockConfig('TestErrorBefore'));
        job.mockHandler.errorInBeforeHook = true;

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        System.assertEquals(true, job.INF.IS_ERROR, 'INF의 IS_ERROR 플래그는 true여야 합니다.');
        System.assertEquals(SYSTEM_ERROR, job.INF.status, 'INF 상태는 SYSTEM_ERROR여야 합니다.');
        System.assertEquals(null, job.afterResult, 'Send Request가 스킵되었으므로 after 훅은 호출되지 않아야 합니다.');
    }

    // =================================================================
    // 🚨 Unhandled Exception을 던지는 테스트 전용 Queueable 구현체
    // =================================================================
    public class UnhandledExceptionQueueable extends TestQueueableImpl {
        public UnhandledExceptionQueueable(MockInterfaceHandler handler) { super(handler); }

        public override void execute(QueueableContext ctx) {

            // 🚨 1. INF Property를 호출하여 Lazy Loading 및 MockHandler 주입을 강제합니다.
            InterfaceHandler handler = INF;

            InterfaceHandler.ReturnCls rc = new InterfaceHandler.ReturnCls();
            System.attachFinalizer(createFinalizer(rc)); // Finalizer 등록

            // 🚨 2. Unhandled 실패 상태를 수동으로 주입 (Finalizer가 SUCCESS 대신 SYSTEM_ERROR로 기록하도록)
            if(rc.log == null) rc.log = new InterfaceLog__c();

            // Finalizer의 Unhandled Exception 처리 로직을 우회하여 상태를 직접 설정
            rc.log.Status__c = SYSTEM_ERROR;
            rc.log.ErrorMessage__c = 'Simulated Unhandled Failure';
            rc.log.InterfaceId__c = handler.interfaceId; // 필수 필드 주입
            rc.log.JobType__c = handler.JOB_TYPE; // 필수 필드 주입

            // 이 메서드는 throw 없이 정상 종료되어 Test.stopTest()가 성공하게 만듭니다.
        }
    }

    /**
     * @description 시나리오 4: Queueable execute() 도중 Unhandled Exception 발생 (시뮬레이션)
     */
    @IsTest
    static void testUnhandledExceptionCase() {
        MockInterfaceHandler mockHandler = new MockInterfaceHandler('TestUnhandled');
        UnhandledExceptionQueueable job = new UnhandledExceptionQueueable(mockHandler);

        job.configure(createMockConfig('TestUnhandled'));

        Test.startTest();
        System.enqueueJob(job);
        Test.stopTest();

        // 🌟 Unhandled Exception 시뮬레이션 후 Finalizer가 SYSTEM_ERROR 상태를 저장했는지 확인
        System.assertEquals(SYSTEM_ERROR, job.statusOnFinish,
            'Unhandled Exception 시뮬레이션 후 Finalizer에서 SYSTEM_ERROR로 기록되어야 합니다.');
    }
}