/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public virtual with sharing class InterfaceHandler {

    // =================================================================
    // Constants & State
    // =================================================================

    public static final String SUCCESS = 'SUCCESS',
        SYSTEM_ERROR = 'SYSTEM ERROR',
        RESPONSE_ERROR = 'RESPONSE ERROR';

    // 식별자 및 로그용
    public String interfaceId;
    public String JOB_TYPE;

    // 실행 상태
    public String status;
    public Boolean IS_ERROR = false;
    public Boolean IS_SKIP = false;
    public Boolean IS_JSON = true; // JSON 직렬화 여부

    // 내부 설정 변수 (setup()을 통해 세팅됨)
    private String configuredEndpoint;
    private String configuredMethod;
    private Integer configuredTimeout;
    private Boolean isConfigured = false;

    // 로그 데이터
    public List<String> keyList = new List<String>();
    public List<String> successList = new List<String>();
    public List<String> failList = new List<String>();

    // 사용자 ID 캐싱
    private static String currentUserId = UserInfo.getUserId();

    // =================================================================
    // Constructor & Setup
    // =================================================================
    public InterfaceHandler(String interfaceId) {
        this.interfaceId = interfaceId;
    }

    /**
     * @description 설정 주입 메소드 (Factory -> Abstract Class -> Service 순으로 호출됨)
     */
    public void setup(InterfaceConfig__mdt config) {
        if (config == null) return;

        // 1. Endpoint 조합 (callout:NamedCredential + Path)
        // Named Credential이 없는 경우(Mock 등)를 대비해 체크
        if (String.isNotBlank(config.NamedCredential__c)) {
            this.configuredEndpoint = 'callout:' + config.NamedCredential__c;
            if (String.isNotBlank(config.ResourcePath__c)) {
                this.configuredEndpoint += config.ResourcePath__c;
            }
        } else {
            // Named Credential이 없으면 Path를 전체 URL로 간주하거나 테스트용
            this.configuredEndpoint = config.ResourcePath__c;
        }

        // 2. Method & Timeout
        this.configuredMethod = String.isNotBlank(config.Method__c) ? config.Method__c : 'POST';
        this.configuredTimeout = (config.Timeout__c != null) ? Integer.valueOf(config.Timeout__c) : 120000;

        this.isConfigured = true;
    }

    // =================================================================
    // Main Method: Send
    // =================================================================

    public virtual ReturnCls send(String requestBody, Map<String, String> headerMap, Map<String, String> qParams, Type responseType) {
        System.debug(LoggingLevel.INFO, '=== InterfaceHandler.send [' + interfaceId + '] ===');

        // 초기화 체크
        if (!this.isConfigured) {
            throw new InterfaceException('InterfaceHandler Not Configured. Call setup() first.');
        }

        ReturnCls rc = new ReturnCls();
        rc.log = new InterfaceLog__c();
        rc.log.InterfaceId__c = interfaceId;
        rc.log.Datetime__c = Datetime.now();
        rc.log.User__c = currentUserId;
        rc.log.Method__c = this.configuredMethod;
        rc.log.JobType__c = JOB_TYPE;

        HttpResponse res = null;
        String responseBody = null;

        try {
            // 1. Validation
            if (String.isBlank(this.configuredEndpoint)) throw new InterfaceException('Endpoint is empty.');

            // 2. HTTP Request 설정
            HttpRequest req = new HttpRequest();

            // Query Params 처리
            String finalEndpoint = this.configuredEndpoint;
            if (qParams != null && !qParams.isEmpty()) {
                // 가정된 유틸리티 클래스 사용
                // UtilHttp.ParameterBuilder urlBuilder = Core.Http2.setEndpoint(finalEndpoint);
                // for (String key : qParams.keySet()) {
                //     urlBuilder.append(key, qParams.get(key));
                // }
                // finalEndpoint = urlBuilder.build();
            }

            // Headers 처리
            if (headerMap != null) {
                for (String key : headerMap.keySet()) {
                    req.setHeader(key, headerMap.get(key));
                }
                if (!headerMap.isEmpty()) rc.log.Headers__c = JSON.serialize(headerMap);
            }

            req.setEndpoint(finalEndpoint);
            req.setMethod(this.configuredMethod);
            req.setTimeout(this.configuredTimeout);

            // Body 설정
            if (shouldSendBody(this.configuredMethod) && String.isNotBlank(requestBody)) {
                req.setBody(requestBody);
            }

            // 3. Send
            System.debug('>> Endpoint: ' + finalEndpoint);
            res = new Http().send(req); // 🚨 실제 콜아웃 지점
            responseBody = res?.getBody();

            rc.responseBody = responseBody;
            rc.statusCode = res?.getStatusCode();

            // 4. Status Check
            // 기본적으로 200, 201을 성공으로 간주
            Integer code = res?.getStatusCode();
            if (res != null && (code == 200 || code == 201 || code == 202)) {
                status = SUCCESS;
            } else {
                status = RESPONSE_ERROR;
                rc.log.ErrorMessage__c = String.isBlank(responseBody) ? String.valueOf(res) : responseBody;
                rc.log.hasFailed__c = true;
            }

        } catch (Exception e) {
            status = SYSTEM_ERROR;
            rc.log.ErrorMessage__c = getExceptionMessage(e);
            rc.log.hasFailed__c = true;
        }

        // 5. Finalize Log
        finalizeLog(rc, status, requestBody, responseBody, qParams, responseType);

        return rc;
    }

    // =================================================================
    // Helper Methods
    // =================================================================

    private Boolean shouldSendBody(String method) {
        if (String.isBlank(method)) return false;
        String m = method.toUpperCase();
        return (m == 'POST' || m == 'PUT' || m == 'PATCH');
    }

    private void finalizeLog(ReturnCls rc, String status, String reqBody, String resBody, Map<String, String> qParams, Type resType) {
        try {
            rc.log.Status__c = status;

            if (resType != null && String.isNotBlank(resBody)) {
                try {
                    rc.responseObject = JSON.deserialize(resBody, resType);
                } catch(Exception e) {
                    rc.log.ErrorMessage__c += '\n[Parsing Error] ' + e.getMessage();
                }
            } else if (String.isNotBlank(resBody)) {
                rc.responseObject = JSON.deserializeUntyped(resBody);
            }

            // -------------------------------------------------------
            // 이후 로그 적재 로직 실행 (여기서 에러 나도 위에서 파싱은 이미 끝남)

            // Request Logging
            if (String.isNotBlank(reqBody)) {
                rc.log.RequestBody__c = chunkBody(reqBody);
            } else if (qParams != null && !qParams.isEmpty()) {
                rc.log.Params__c = JSON.serialize(qParams);
            }

            // Response Logging (Split) - 필드 없으면 여기서 에러 날 수 있음
            splitBody(resBody, rc.log);

        } catch (Exception e) {
            // splitBody 등에서 에러 나면 여기에 잡힘
            System.debug('Log Finalize Error: ' + e.getMessage());
            rc.log.ErrorMessage__c = getExceptionMessage(e);
        }
    }

    /**
     * @description 시스템 에러 발생 시 로그를 즉시 기록합니다. (Queueable의 try-catch 블록에서 호출)
     */
    public virtual void error(Exception e) { // 🚨 virtual 추가
        ReturnCls rc = new ReturnCls();
        rc.log = new InterfaceLog__c();
        rc.log.InterfaceId__c = interfaceId;
        rc.log.Datetime__c = Datetime.now();
        rc.log.JobId__c = System.UUID.randomUUID().toString().replaceAll('-', '');
        rc.log.Status__c = SYSTEM_ERROR;
        rc.log.ErrorMessage__c = getExceptionMessage(e);
        rc.log.JobType__c = JOB_TYPE;
        rc.log.hasFailed__c = true;
        IS_ERROR = true;

        // DML을 유발하는 지점. LogCls가 virtual이어야 테스트에서 Mocking 가능.
        new LogCls(rc).execute();
    }

    public static String getExceptionMessage(Exception e) {
        return e?.getTypeName() + ' : ' + e?.getMessage() + '\n' + e?.getStackTraceString();
    }

    private static String chunkBody(String body) {
        return String.isNotBlank(body) ? body.left(131072) : body;
    }

    private static void splitBody(String body, InterfaceLog__c log) {
        if (String.isBlank(body)) return;
        Integer chunkSize = 131072;
        Integer numChunks = (body.length() + chunkSize - 1) / chunkSize;
        for (Integer i = 0; i < numChunks && i < 5; i++) {
            Integer s = i * chunkSize;
            Integer e = Math.min(s + chunkSize, body.length());
            log.put('ResponseBody' + (i + 1) + '__c', body.substring(s, e));
        }
    }

    public class InterfaceException extends Exception {}

    // =================================================================
    // Inner Classes
    // =================================================================
    public class ReturnCls {
        public String responseBody;
        public Object responseObject;
        public String requestBody;
        public InterfaceLog__c log;
        public Decimal statusCode;
        public Boolean isError = false;
        public Boolean manualLogging = false;
    }

    /**
     * @description DML을 담당하는 클래스. 테스트 가능하도록 virtual로 변경
     */
    public virtual class LogCls { // 🚨 virtual 추가
        public InterfaceLog__c log;
        public Boolean manualLogging;
        public LogCls(ReturnCls rc) {
            this.log = rc.log;
            this.manualLogging = rc.manualLogging;
        }

        public virtual void execute() { // 🚨 virtual 추가
            if (log == null) return;
            // manualLogging 처리 로직이 있다면 여기에 Bulk Add
            insert log; // 🚨 DML 발생 지점
        }
    }
}