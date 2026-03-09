/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-01      jh.jung           Created
*/
public abstract without sharing class InterfaceQueueable implements Queueable, Database.AllowsCallouts, IInterfaceExecutor {

    // =================================================================
    // 1. Constants & State Variables
    // =================================================================
    private static final String JOB_TYPE = 'Queueable';

    // 메타데이터 설정 (Factory 주입)
    protected InterfaceConfig__mdt config;

    // Legacy 호환 및 내부 변수
    protected String interfaceName;
    protected Type responseType;

    // [캡슐화] 요청 데이터 객체
    protected Object request;

    // 상태 변수
    protected Map<String, String> queryParameterMap = new Map<String, String>();
    protected Map<String, String> headerMap = new Map<String, String>();

    // Lazy Loading Service
    public InterfaceHandler INF {
        get {
            if (INF == null) {
                System.debug('INF get START');
                // Config 우선, 없으면 Legacy 이름 사용
                String svcName = (config != null && config.DeveloperName != null) ? config.DeveloperName : this.interfaceName;
                INF = createService(svcName);
                INF.JOB_TYPE = JOB_TYPE;

                // 설정 주입
                if (config != null) {
                    INF.setup(config);
                }
            }
            return INF;
        }
        set;
    }

    // =================================================================
    // 2. Constructors & Configuration
    // =================================================================

    /** @description Factory용 기본 생성자 */
    public InterfaceQueueable() {}

    /** @description Legacy 생성자 */
    public InterfaceQueueable(String interfaceName, Type responseType) {
        this.interfaceName = interfaceName;
        this.responseType = responseType;
    }

    /** @description [IInterfaceExecutor] 설정 주입 */
    public void configure(InterfaceConfig__mdt config) {
        this.config = config;
        this.interfaceName = config.DeveloperName;
    }

    protected void setResponseType(Type responseType) {
        this.responseType = responseType;
    }

    /** @description Test Hook */
    @TestVisible
    protected virtual InterfaceHandler createService(String name) {
        return new InterfaceHandler(name);
    }

    /** 🚨 [추가] Finalizer Mocking을 위한 Factory 메서드 */
    @TestVisible
    protected virtual System.Finalizer createFinalizer(InterfaceHandler.ReturnCls rc) {
        return new QueueableFinalizer(rc, this);
    }


    // =================================================================
    // 3. IInterfaceExecutor Implementation (Entry Point)
    // =================================================================

    /**
     * @description [IInterfaceExecutor 구현] 요청 데이터를 받아 내부 변수에 할당 후 실행합니다.
     * @param requestData 전송할 요청 데이터 객체
     * @return 실행 결과 객체 (InterfaceHandler.ReturnCls)
     */
    public Object call(Object requestData) {

        // 1. 요청 데이터를 내부 변수에 할당 (setRequestData 역할 대체)
        this.request = requestData;

        System.debug(JSON.serialize(this.request));
        System.debug(JSON.serialize(requestData));

        // 2. 요청 데이터가 할당된 상태에서 기존 템플릿 메서드 호출
        return System.enqueueJob(this);
//        return '000000000000000000';
    }

    /**
     * @description Factory에서 호출. Queueable을 Enqueue한다.
     * @return Job ID (Id)
     */
    public virtual Object call() {
        return System.enqueueJob(this);
    }

    public void addHeader(String key, String value) {
        this.headerMap.put(key, value);
    }

    public void addQueryParam(String key, String value) {
        this.queryParameterMap.put(key, value);
    }

    // =================================================================
    // 4. Abstract Methods
    // =================================================================
    public abstract Object before();
    public abstract void after(InterfaceHandler.ReturnCls rc);

    /** @description Finalizer에서 호출될 종료 훅 */
    public virtual void finish(InterfaceHandler.ReturnCls rc) { // 🚨 public virtual 유지
        System.debug('Default finish() execution.');
    }

    // =================================================================
    // 5. Queueable Execution Logic
    // =================================================================

    public virtual void execute(QueueableContext ctx) {
        System.debug(LoggingLevel.INFO, '=== Queueable Execute ===');
        String jobId = ctx.getJobId();

        // 🚨 1. INF Property를 호출하여 Lazy Loading 및 MockHandler 주입을 강제합니다.
        InterfaceHandler handler = INF;

        // 2. Finalizer 등록 및 로그 객체 초기화
        InterfaceHandler.ReturnCls rc = new InterfaceHandler.ReturnCls();
        rc.log = new InterfaceLog__c(); // 로그 객체 생성

        // 🚨 3. 필수 로깅 필드 초기화 (누락된 필드 채우기)
        rc.log.JobId__c = jobId;
        rc.log.InterfaceId__c = handler.interfaceId;
        rc.log.JobType__c = handler.JOB_TYPE;

        // Finalizer 등록 (수정된 Factory 메서드 호출)
        System.attachFinalizer(createFinalizer(rc));

        try {
            // 1. Skip Check
            if (INF.IS_SKIP) {
                System.debug('INF.IS_SKIP is True. Job Skipped.');
                return;
            }

            // 2. Before Hook
            Object result = before();

            // Before 에러 체크
            if (INF.IS_ERROR) return;

            // 3. Send Request
            InterfaceHandler.ReturnCls sendResult = sendRequest(result);

            // 🚨 4. Finalizer가 참조하는 원본 rc 객체에 내용 복사 (rc.log는 sendResult.log 내용으로 업데이트)
            rc.responseBody = sendResult.responseBody;
            rc.responseObject = sendResult.responseObject;

            if (sendResult.log != null) {
                // rc.log 필드만 업데이트 (JobId 등은 그대로 유지됨)
                rc.log.Status__c = sendResult.log.Status__c;
                rc.log.ErrorMessage__c = sendResult.log.ErrorMessage__c;
            }

            // 5. After Hook
            if (InterfaceHandler.SUCCESS.equals(INF.status)) {
                success(rc);
            } else {
                fail(rc, INF.status);
            }

        } catch (Exception e) {
            // Unhandled Exception 발생 시
            INF.error(e);

            // Finalizer가 SYSTEM_ERROR 상태를 볼 수 있도록 rc에 최종 정보를 담아줌
            rc.log.Status__c = InterfaceHandler.SYSTEM_ERROR;
            rc.log.ErrorMessage__c = InterfaceHandler.getExceptionMessage(e);
            // JobId, InterfaceId 등은 이미 설정됨
        }
    }

    // =================================================================
    // 6. Helpers
    // =================================================================

    private InterfaceHandler.ReturnCls sendRequest(Object result) {

        String bodyToSend = INF.IS_JSON ? JSON.serialize(result) : String.valueOf(result);

        // 간소화된 호출
        return INF.send(bodyToSend, headerMap, queryParameterMap, responseType);
    }

    private void success(InterfaceHandler.ReturnCls rc) {
        after(rc);
        updateLogData(rc);
    }

    private void fail(InterfaceHandler.ReturnCls rc, String status) {
        // Log 데이터가 null이 아님을 보장 (execute 시작 시 생성됨)
        if(rc.log == null) rc.log = new InterfaceLog__c();

        rc.log.Status__c = status;
        rc.log.ErrorMessage__c = rc.responseBody;
        updateLogData(rc);
    }

    private void updateLogData(InterfaceHandler.ReturnCls rc) {
        if (rc.log != null) {
            rc.log.Key__c = String.join(INF.keyList, ',');
            rc.log.Success__c = String.join(INF.successList, ',');
            rc.log.Fail__c = String.join(INF.failList, ',');
        }
    }

    // =================================================================
    // 7. Finalizer (Guarantees Logging)
    // =================================================================
    public virtual class QueueableFinalizer implements System.Finalizer { // 🚨 virtual 유지
        protected final InterfaceHandler.ReturnCls rc; // 🚨 protected final 유지
        protected final InterfaceQueueable jobInstance; // 🚨 protected final 유지

        public QueueableFinalizer(InterfaceHandler.ReturnCls rc, InterfaceQueueable instance) {
            // rc가 null일 경우를 대비해 빈 객체 생성 (방어 코드)
            this.rc = (rc != null) ? rc : new InterfaceHandler.ReturnCls();
            this.jobInstance = instance;
        }

        public virtual void execute(FinalizerContext ctx) { // 🚨 virtual 유지
            System.debug(LoggingLevel.INFO, '=== Queueable Finalizer ===');

            // 1. Unhandled Exception 처리 (Queueable 자체가 터진 경우)
            if (ctx.getResult() == ParentJobResult.UNHANDLED_EXCEPTION) {
                Exception e = ctx.getException();
                if (rc.log == null) rc.log = new InterfaceLog__c();

                rc.log.Status__c = InterfaceHandler.SYSTEM_ERROR;
                rc.log.ErrorMessage__c = 'Unhandled Queueable Error: ' + e.getMessage() + '\n' + e.getStackTraceString();
                rc.log.JobId__c = ctx.getAsyncApexJobId(); // 터졌을 땐 Context ID 사용
            }

            // 2. 로그 저장
            if (jobInstance != null) {
                // LogCls를 통해 저장 (Bulk 처리 가능성 열어둠)
                new InterfaceHandler.LogCls(rc).execute();

                // 3. Finish 훅 실행
                jobInstance.finish(rc);
            }
        }
    }
}