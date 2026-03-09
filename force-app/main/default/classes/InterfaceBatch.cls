/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-01      jh.jung           Created
*/
/**
 * @description Batch 인터페이스를 위한 공통 추상 클래스입니다.
 * Database.Batchable, Stateful을 구현하여 대량 데이터 처리 및 상태 유지를 지원합니다.
 * * [주요 특징]
 * 1. InterfaceFactory를 통한 생성 및 설정 주입 지원 (IInterfaceExecutor 구현)
 * 2. Database.Stateful을 통해 배치 실행 간 설정(Config) 및 상태 유지
 * 3. Mock 테스트 시 직렬화 오류 방지를 위해 Config 객체는 JSON String으로 관리
 * 4. 배치 라이프사이클(Start -> Execute -> Finish)별 공통 로깅 및 에러 처리 자동화
 */
public abstract without sharing class InterfaceBatch implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts, IInterfaceExecutor {

    // =================================================================
    // 1. 상수 및 상태 변수 (Constants & State Variables)
    // =================================================================

    // 테스트 코드에서 강제 에러 유발을 위한 플래그 (IS_TEST 제거됨)
    @TestVisible protected Boolean makeAnError = false;

    // 로그에 기록될 Job Type 상수
    private final static String JOB_TYPE_START = 'Batch (Start)';
    private final static String JOB_TYPE_EXECUTE = 'Batch (Execute)';
    private final static String JOB_TYPE_FINISH = 'Batch (Finish)';

    // [Stateful 저장 대상]
    // Mock Config(가짜 SObject) 직렬화 오류 방지를 위해 JSON String으로 저장합니다.
    protected String configJson;

    protected String interfaceName;
    protected Type responseType; // 응답 파싱용 클래스 타입

    // 배치 실행 상태 관리를 위한 변수
    private Integer index = 1; // 배치 청크 인덱스 (JobId-1, JobId-2...)
    protected Boolean RUN_ON_ERROR = true; // 에러 발생 시 다음 청크 실행 여부
    protected Boolean HAS_FAIL = false; // 전체 배치 중 실패 발생 여부

    // [캡슐화] 요청 데이터 객체
    protected Object request;

    // 파라미터 맵 (헤더 및 쿼리 스트링)
    protected Map<String, String> queryParameterMap = new Map<String, String>();
    protected Map<String, String> headerMap = new Map<String, String>();

    // 통신 핸들러 (Lazy Loading & Transient)
    // 배치가 직렬화될 때 핸들러 객체가 유실될 수 있으므로, 없을 경우 Config를 기반으로 재생성합니다.
    private transient InterfaceHandler localInf;

    public InterfaceHandler INF {
        get {
            if (localInf == null) {
                // 저장된 JSON Config를 객체로 복원
                InterfaceConfig__mdt configObj = null;
                if (String.isNotBlank(this.configJson)) {
                    configObj = (InterfaceConfig__mdt) JSON.deserialize(this.configJson, InterfaceConfig__mdt.class);
                }

                // 핸들러 이름 결정 (Config 우선)
                String svcName = (configObj != null && configObj.DeveloperName != null) ? configObj.DeveloperName : this.interfaceName;
                localInf = createService(svcName);

                // 서비스 초기화 (설정 주입)
                if (configObj != null) {
                    localInf.setup(configObj);
                }
            }
            return localInf;
        }
        set { localInf = value; }
    }

    // =================================================================
    // 2. 생성자 및 설정 (Constructors & Configuration)
    // =================================================================

    /** @description Factory용 기본 생성자 */
    public InterfaceBatch() {}

    /** @description Legacy용 생성자 */
    protected InterfaceBatch(String interfaceName, Type responseType) {
        this(interfaceName, responseType, true);
    }

    /** * @description Legacy용 생성자 (옵션 포함)
     * @param runOnError 에러 발생 시에도 남은 배치를 계속 수행할지 여부
     */
    protected InterfaceBatch(String interfaceName, Type responseType, Boolean runOnError) {
        this.interfaceName = interfaceName;
        this.responseType = responseType;
        this.RUN_ON_ERROR = runOnError;
    }

    /**
     * @description [IInterfaceExecutor 구현] Factory에서 설정을 주입할 때 호출
     * SObject 직렬화 이슈 방지를 위해 JSON 문자열로 변환하여 저장합니다.
     */
    public void configure(InterfaceConfig__mdt config) {
        if (config != null) {
            this.configJson = JSON.serialize(config);
            this.interfaceName = config.DeveloperName;
        }
    }

    /**
     * @description 응답 데이터를 특정 클래스 타입으로 파싱하고 싶을 때 호출
     */
    protected void setResponseType(Type responseType) {
        this.responseType = responseType;
    }

    /** @description [Test Hook] 테스트용 가짜 핸들러 주입을 위한 가상 메서드 */
    @TestVisible
    protected virtual InterfaceHandler createService(String name) {
        return new InterfaceHandler(name);
    }

    // =================================================================
    // 3. IInterfaceExecutor 구현 (진입점)
    // =================================================================

    /**
     * @description [IInterfaceExecutor 구현] 요청 데이터를 받아 내부 변수에 할당 후 실행합니다.
     * @param requestData 전송할 요청 데이터 객체
     * @return 실행 결과 객체 (InterfaceHandler.ReturnCls)
     */
    public Object call(Object requestData) {
        // 1. 요청 데이터를 내부 변수에 할당 (setRequestData 역할 대체)
        this.request = requestData;

        // 2. 요청 데이터가 할당된 상태에서 기존 템플릿 메서드 호출
        return this.call();
    }

    /**
     * @description 배치를 시작합니다.
     * @return Batch Job ID
     */
    public Object call() {
        Integer batchSize = 200; // 기본값

        // Config JSON에서 배치 사이즈 설정 확인
        if (String.isNotBlank(this.configJson)) {
            InterfaceConfig__mdt configObj = (InterfaceConfig__mdt) JSON.deserialize(this.configJson, InterfaceConfig__mdt.class);
            if (configObj.BatchSize__c != null) {
                batchSize = Integer.valueOf(configObj.BatchSize__c);
            }
        }
        return Database.executeBatch(this, batchSize);
    }

    public void addHeader(String key, String value) {
        this.headerMap.put(key, value);
    }

    public void addQueryParam(String key, String value) {
        this.queryParameterMap.put(key, value);
    }

    // =================================================================
    // 4. 추상 메서드 - 자식 클래스 구현 의무 (Abstract Methods)
    // =================================================================

    protected abstract Database.QueryLocator startBatch(Database.BatchableContext BC);
    protected abstract Object before(Database.BatchableContext BC, List<SObject> scope);
    protected abstract void after(InterfaceHandler.ReturnCls rc);
    protected abstract void finishBatch(Database.BatchableContext BC);

    // =================================================================
    // 5. 배치 인터페이스 구현 (Database.Batchable)
    // =================================================================

    /**
     * @description 배치 시작 (Start)
     */
    public Database.QueryLocator start(Database.BatchableContext BC) {
        System.debug(LoggingLevel.INFO, '=== Batch Start ===');
        try {
            return startBatch(BC);
        } catch (Exception e) {
            INF.JOB_TYPE = JOB_TYPE_START;
            INF.error(e);

            // 주의: 에러 발생 시 null을 리턴하면 System.UnexpectedException 발생
            // 따라서 결과가 0건인 빈 쿼리를 리턴하여 조용히 종료시킴
            return Database.getQueryLocator('SELECT Id FROM Account LIMIT 0');
        }
    }

    /**
     * @description 배치 실행 (Execute)
     */
    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        System.debug(LoggingLevel.INFO, '=== Batch Execute ===');
        INF.JOB_TYPE = JOB_TYPE_EXECUTE;
        String jobId = BC.getJobId();

        // 이전 청크의 실패 여부 확인 및 중단 로직
        if (INF.IS_ERROR) HAS_FAIL = true;
        if (!RUN_ON_ERROR && HAS_FAIL) return;
        if (RUN_ON_ERROR) INF.IS_ERROR = false;

        // 결과 객체 생성 (생성자에서 log 자동 생성)
        InterfaceHandler.ReturnCls rc = new InterfaceHandler.ReturnCls();

        try {
            // 1. Before Hook (요청 데이터 준비)
            Object result = before(BC, scope);

            // Before 단계 에러 체크
            if (INF.IS_ERROR) return;

            // 2. Send Request
            // 결과가 null이 아닐 때만 덮어씌워 NPE 방지
            InterfaceHandler.ReturnCls resultRc = sendRequest(result);
            if (resultRc != null) rc = resultRc;

            // 3. Job ID 세팅 (BatchID + Index 조합)
            prepareLog(rc, jobId);

            // 로직상 발생한 에러 체크
            if (rc.isError || (rc.log != null && String.isNotBlank(rc.log.ErrorMessage__c))) {
                throw new InterfaceHandler.InterfaceException();
            }

            // 테스트 강제 에러
            if (makeAnError) throw new CalloutException('Test Batch Error');

            // 4. After Hook (응답 처리)
            if (InterfaceHandler.SUCCESS.equals(INF.status)) {
                after(rc);
                updateLogData(rc);
            } else {
                updateLogData(rc);
            }

        } catch (Exception e) {
            // 예외 처리
            handleException(rc, e, jobId);
            HAS_FAIL = true;
        }

        // 5. 로그 저장
        new InterfaceHandler.LogCls(rc).execute();
    }

    /**
     * @description 배치 종료 (Finish)
     */
    public void finish(Database.BatchableContext BC) {
        System.debug(LoggingLevel.INFO, '=== Batch Finish ===');
        try {
            finishBatch(BC);
        } catch (Exception e) {
            INF.JOB_TYPE = JOB_TYPE_FINISH;
            INF.error(e);
        }
    }

    // =================================================================
    // 6. 내부 헬퍼 메서드 (Helpers)
    // =================================================================

    private InterfaceHandler.ReturnCls sendRequest(Object result) {
        String bodyToSend = INF.IS_JSON ? JSON.serialize(result) : String.valueOf(result);
        // 저장된 Type 객체를 바로 사용하여 전송
        return INF.send(bodyToSend, headerMap, queryParameterMap, this.responseType);
    }

    /**
     * @description 배치 전용 로그 ID 생성 (JobId-Index 형식)
     */
    private void prepareLog(InterfaceHandler.ReturnCls rc, String jobId) {
        if (rc == null) return;
        if (rc.log == null) rc.log = new InterfaceLog__c();

        // Job ID가 없을 때만 생성 (덮어쓰기 방지)
        if (String.isBlank(rc.log.JobId__c)) {
            rc.log.JobId__c = jobId + '-' + (index++);
            rc.log.JobType__c = JOB_TYPE_EXECUTE;
        }
    }

    private void handleException(InterfaceHandler.ReturnCls rc, Exception e, String jobId) {
        if (rc == null) rc = new InterfaceHandler.ReturnCls();
        if (rc.log == null) rc.log = new InterfaceLog__c();

        // ★ [수정] 이미 RESPONSE_ERROR라면(API 실패), SYSTEM_ERROR로 덮어쓰지 않음
        if (rc.log.Status__c != InterfaceHandler.RESPONSE_ERROR) {
            rc.log.Status__c = InterfaceHandler.SYSTEM_ERROR;
        }

        // 에러 메시지 처리 (기존 메시지 유지 또는 시스템 예외 메시지 추가)
        String exMsg = InterfaceHandler.getExceptionMessage(e);
        // InterfaceException은 우리가 일부러 던진 거니까 스택트레이스 굳이 안 남겨도 됨 (선택 사항)
        if (!(e instanceof InterfaceHandler.InterfaceException)) {
            rc.log.ErrorMessage__c = String.isNotBlank(rc.log.ErrorMessage__c) ? rc.log.ErrorMessage__c + '\n' + exMsg : exMsg;
        }

        rc.isError = true;

        prepareLog(rc, jobId);
    }

    private void updateLogData(InterfaceHandler.ReturnCls rc) {
        if (rc.log != null) {
            rc.log.Key__c = String.join(INF.keyList, ',');
            rc.log.Success__c = String.join(INF.successList, ',');
            rc.log.Fail__c = String.join(INF.failList, ',');
        }
    }
}