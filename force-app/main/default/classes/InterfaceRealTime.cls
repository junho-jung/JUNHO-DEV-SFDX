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
 * @description Real-Time (실시간) 인터페이스를 위한 추상 부모 클래스입니다.
 * 모든 실시간 인터페이스 구현체는 이 클래스를 상속받아 구현해야 합니다.
 * * [주요 역할]
 * 1. Factory로부터 설정(Metadata)을 주입받아 통신 환경을 구성합니다.
 * 2. Template Method 패턴을 사용하여 전체 실행 흐름(Before -> Send -> After)을 제어합니다.
 * 3. 예외 처리 및 로그 적재를 공통으로 수행하여 구현체의 부담을 줄입니다.
 *
 * @author  YourName
 * @date    2024-XX-XX
 */
public abstract without sharing class InterfaceRealTime implements IInterfaceExecutor {

    // =================================================================
    // 1. 상수 및 상태 변수 (Constants & State Variables)
    // =================================================================

    // 로그에 기록될 Job Type
    private static final String JOB_TYPE = 'Real-Time';

    // Factory에서 주입되는 메타데이터 설정 정보
    protected InterfaceConfig__mdt config;

    // [Legacy 호환] 메타데이터가 없는 경우를 위한 내부 변수들
    protected String interfaceName;
    protected Type responseType;
    protected Boolean isManualLogging = false;

    // 테스트 코드에서 강제로 에러를 유발하기 위한 플래그
    @TestVisible public Boolean makeAnError = false;

    // [캡슐화] 요청 데이터 객체
    protected Object request;

    // 하위 구현체에서 헤더나 쿼리 파라미터를 추가할 때 사용하는 맵
    protected Map<String, String> queryParameterMap = new Map<String, String>();
    protected Map<String, String> headerMap = new Map<String, String>();

    // [핵심] 통신 및 로깅을 담당하는 핸들러 (Lazy Loading 적용)
    // - get 호출 시점에 설정(Config)을 주입하여 초기화합니다.
    public InterfaceHandler INF {
        get {
            if (INF == null) {
                // 1. 핸들러 이름 결정 (Config 우선, 없으면 Legacy 이름)
                String svcName = (config != null && config.DeveloperName != null) ? config.DeveloperName : this.interfaceName;

                // 2. 가상 메서드를 통해 핸들러 생성 (테스트 시 Mocking 가능)
                INF = createService(svcName);
                INF.JOB_TYPE = JOB_TYPE;

                // 3. 설정 주입 (Stateful: URL, Method 등을 핸들러가 기억하게 함)
                if (config != null) {
                    INF.setup(config);
                }
            }
            return INF;
        }
        set;
    }

    // =================================================================
    // 2. 생성자 및 설정 (Constructors & Configuration)
    // =================================================================

    /**
     * @description 기본 생성자. InterfaceFactory에서 newInstance()로 호출할 때 사용됩니다.
     */
    public InterfaceRealTime() {}

    /**
     * @description [IInterfaceExecutor 구현] Factory에서 설정을 주입할 때 호출합니다.
     * @param config InterfaceConfig__mdt 레코드
     */
    public void configure(InterfaceConfig__mdt config) {
        this.config = config;
        this.interfaceName = config.DeveloperName; // 로깅을 위해 이름 동기화
    }

    /**
     * @description [Test Hook] 테스트 코드에서 가짜 핸들러를 주입할 수 있도록 가상 메서드로 분리했습니다.
     */
    @TestVisible
    protected virtual InterfaceHandler createService(String name) {
        return new InterfaceHandler(name);
    }

    /**
     * @description 응답 데이터를 특정 클래스 타입으로 파싱하고 싶을 때 자식 클래스 생성자에서 호출합니다.
     */
    protected void setResponseType(Type responseType) {
        this.responseType = responseType;
    }

    // =================================================================
    // 3. 헬퍼 메서드 - 헤더/파라미터 (Helper Methods)
    // =================================================================

    public void addHeader(String key, String value) {
        this.headerMap.put(key, value);
    }

    public void addQueryParam(String key, String value) {
        this.queryParameterMap.put(key, value);
    }

    // =================================================================
    // 4. 추상 메서드 - 자식 클래스 구현 의무 (Abstract Methods)
    // =================================================================

    /**
     * @description 통신 전, 요청 데이터를 가공하는 단계입니다.
     * @return 전송할 데이터 객체 (Map, List, Wrapper Class 등)
     */
    public abstract Object before();

    /**
     * @description 통신 성공 후, 응답 데이터를 처리하는 단계입니다. (DML 등)
     * @param rc 결과 객체
     */
    public abstract void after(InterfaceHandler.ReturnCls rc);

    /**
     * @description (선택) 모든 처리가 끝난 후 마무리 작업을 수행합니다.
     */
    public virtual void finish() {}

    // =================================================================
    // 5. 실행 로직 - 템플릿 메서드 (Execution Logic)
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
     * @description 인터페이스 실행의 진입점입니다. 전체 흐름을 제어하고 예외를 처리합니다.
     * @return 실행 결과 객체 (InterfaceHandler.ReturnCls)
     */
    public Object call() {
        System.debug(LoggingLevel.INFO, '=== [Start] InterfaceRealTime Execute ===');

        // 1. 결과 객체 초기화 (생성자에서 내부 로그 객체도 함께 생성되어 NPE 방지)
        InterfaceHandler.ReturnCls rc = new InterfaceHandler.ReturnCls();

        try {
            // ---------------------------------------------------------
            // STEP 1: Before Hook (요청 데이터 준비)
            // ---------------------------------------------------------
            Object result = null;
            try {
                result = before();
            } catch (Exception e) {
                // Before 단계에서 에러 발생 시 즉시 로그를 남기고 종료합니다.
                INF.error(e);
                return null;
            }

            // 핸들러 내부 로직에 의해 에러나 스킵 플래그가 켜졌다면 중단합니다.
            if (INF.IS_ERROR) return null;

            // ---------------------------------------------------------
            // STEP 2: Send Request (통신 수행)
            // ---------------------------------------------------------
            // 통신 결과가 null일 경우(Mock 실수 등)를 대비해 임시 변수에 담습니다.
            InterfaceHandler.ReturnCls resultRc = sendRequest(result);

            // 결과가 정상적으로 반환되었을 때만 덮어씌워 NPE를 방지합니다.
            if (resultRc != null) {
                rc = resultRc;
            }

            // 매뉴얼 로깅 설정 동기화
            rc.manualLogging = this.isManualLogging;

            // ---------------------------------------------------------
            // STEP 3: After Hook (응답 처리)
            // ---------------------------------------------------------
            handleResponse(rc);

        } catch (Exception e) {
            // 예기치 못한 시스템 에러를 잡아내어 로그를 남깁니다.
            handleException(rc, e);
            return null;
        }

        return rc;
    }

    // =================================================================
    // 6. 내부 로직 헬퍼 (Internal Helpers)
    // =================================================================

    /**
     * @description 실제 HTTP 통신을 요청합니다.
     */
    private InterfaceHandler.ReturnCls sendRequest(Object result) {
        // Body 직렬화 (JSON or String)
        String bodyToSend = INF.IS_JSON ? JSON.serialize(result) : String.valueOf(result);

        // 핸들러에게 전송 위임 (URL, Method 등은 INF가 Config를 통해 이미 알고 있음)
        return INF.send(bodyToSend, headerMap, queryParameterMap, responseType);
    }

    /**
     * @description 응답 결과를 받아 성공/실패를 판단하고 후처리를 진행합니다.
     */
    private void handleResponse(InterfaceHandler.ReturnCls rc) {
        // 방어 코드: rc가 null이면 로직을 진행할 수 없음
        if (rc == null) return;

        String status = INF.status;
        prepareLog(rc); // 로그 적재를 위한 Job ID 확인/생성

        // [Test Only] 테스트 코드에서 강제 예외 발생 시뮬레이션
        if (makeAnError) throw new CalloutException('Test Exception Triggered');

        // 성공 여부 분기
        if (InterfaceHandler.SUCCESS.equals(status)) {
            // 성공: 자식 클래스의 after() 호출
            after(rc);
            updateLogData(rc);
        } else {
            // 실패: 에러 로그 업데이트
            System.debug(LoggingLevel.INFO, 'ERROR in InterfaceRealTime');
            updateLogData(rc);

            if (rc.log != null) {
                rc.log.Status__c = status;
                rc.log.ErrorMessage__c = rc.responseBody;
            }
        }

        // 공통 마무리 (로그 저장 및 finish 호출)
        saveLogAndFinish(rc);
    }

    /**
     * @description try-catch에서 잡힌 예외를 로그에 기록합니다.
     */
    private void handleException(InterfaceHandler.ReturnCls rc, Exception e) {
        // 예외 상황에서는 rc가 불완전할 수 있으므로 안전하게 재생성 보장
        if (rc == null) rc = new InterfaceHandler.ReturnCls();
        if (rc.log == null) rc.log = new InterfaceLog__c();

        rc.log.Status__c = InterfaceHandler.SYSTEM_ERROR;
        rc.log.ErrorMessage__c = InterfaceHandler.getExceptionMessage(e);

        // Job ID가 누락되었을 경우 보정
        prepareLog(rc);

        // 공통 마무리
        saveLogAndFinish(rc);
    }

    /**
     * @description 로그 객체의 필수 값(Job ID)을 보장합니다.
     * 이미 생성된 Job ID가 있다면 유지합니다 (덮어쓰기 방지).
     */
    private void prepareLog(InterfaceHandler.ReturnCls rc) {
        if (rc == null) return;
        if (rc.log == null) rc.log = new InterfaceLog__c();

        if (String.isBlank(rc.log.JobId__c)) {
            rc.log.JobId__c = System.UUID.randomUUID().toString().replaceAll('-', '');
            rc.log.JobType__c = INF.JOB_TYPE;
        }
    }

    /**
     * @description 로그에 검색 키워드(Key) 및 성공/실패 목록을 업데이트합니다.
     */
    private void updateLogData(InterfaceHandler.ReturnCls rc) {
        if (rc.log != null) {
            rc.log.Key__c = String.join(INF.keyList, ',');
            rc.log.Success__c = String.join(INF.successList, ',');
            rc.log.Fail__c = String.join(INF.failList, ',');
        }
    }

    /**
     * @description 로그를 저장하고 finish 메서드를 호출하는 공통 종료 로직입니다.
     */
    private void saveLogAndFinish(InterfaceHandler.ReturnCls rc) {
        // LogCls를 통해 로그 적재 (Bulk 처리 가능성 열어둠)
        new InterfaceHandler.LogCls(rc).execute();

        // 매뉴얼 로깅이 켜져있다면 finish() 호출
        if (this.isManualLogging) finish();
    }
}