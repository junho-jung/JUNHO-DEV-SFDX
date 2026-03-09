/**
 * [2단계] 인바운드 REST 공통 처리기.
 *
 * @Description 요청 파싱·응답 설정·로깅(InterfaceLog__c)을 공통 처리.
 *              IF_SecurityActionController 등에서 IInboundAction 구현체만 주입하면 비즈니스 로직 실행.
 * @see IInboundAction
 * @see IF_SecurityActionController
 */
public with sharing class InboundRestHandler {

    public static final String JOB_TYPE_INBOUND = 'Inbound';

    /**
     * 인바운드 처리 결과 (statusCode + JSON 직렬화 가능한 body)
     * Apex 이너클래스는 static 메서드 미지원 → 생성은 외부 resultOk/resultError 사용
     */
    public class InboundResult {
        public Integer statusCode;
        public Object body;
        public String errorMessage;
        public InboundResult(Integer statusCode, Object body) {
            this.statusCode = statusCode;
            this.body = body;
        }
    }

    /** 성공 결과 생성 (200) */
    public static InboundResult resultOk(Object body) {
        return new InboundResult(200, body);
    }

    /** 에러 결과 생성 (statusCode + error 메시지) */
    public static InboundResult resultError(Integer statusCode, String message) {
        InboundResult r = new InboundResult(statusCode, new Map<String, Object>{ 'error' => message });
        r.errorMessage = message;
        return r;
    }

    /**
     * [2단계] 인바운드 요청 처리 진입점. 요청 파싱 → action.run() → 응답 설정 → InterfaceLog__c 로깅
     */
    public static void run(RestRequest req, RestResponse res, String endpointId, IInboundAction action) {
        String method = req != null ? req.httpMethod : 'GET';
        String requestBody = req != null && req.requestBody != null ? req.requestBody.toString() : '';
        Map<String, String> params = new Map<String, String>();
        if (req != null && req.params != null) {
            params.putAll(req.params);
        }
        String requestUri = req != null ? req.requestURI : '';

        SecuritySoarTrace.log('InboundRestHandler.run.start', new Map<String, Object>{
            'endpointId' => endpointId,
            'method' => method,
            'requestUri' => requestUri
        });

        InboundResult result = null;
        try {
            result = action.run(method, requestBody, params);
            if (result == null) {
                result = resultError(500, 'No response from handler');
            }
        } catch (Exception e) {
            result = resultError(500, e.getMessage() + '\n' + e.getStackTraceString());
        }

        if (res != null) {
            res.statusCode = result.statusCode != null ? result.statusCode : 500;
            res.addHeader('Content-Type', 'application/json; charset=utf-8');
            res.responseBody = Blob.valueOf(JSON.serialize(result.body));
        }

        SecuritySoarTrace.log('InboundRestHandler.run.end', new Map<String, Object>{
            'endpointId' => endpointId,
            'statusCode' => result != null ? result.statusCode : null
        });

        logInbound(endpointId, method, requestUri, requestBody, params, result);
    }

    /**
     * InterfaceLog__c에 인바운드 요청/응답 기록 (Outbound와 동일 오브젝트, JobType = Inbound)
     */
    private static void logInbound(
        String endpointId,
        String method,
        String requestUri,
        String requestBody,
        Map<String, String> params,
        InboundResult result
    ) {
        try {
            InterfaceLog__c log = new InterfaceLog__c();
            log.InterfaceId__c = endpointId;
            log.Datetime__c = Datetime.now();
            try {
                log.User__c = UserInfo.getUserId();
            } catch (Exception ignored) {
                log.User__c = null; // 비로그인(Site Guest 등) 요청
            }
            log.Method__c = method;
            log.JobType__c = JOB_TYPE_INBOUND;
            log.Status__c = result.statusCode >= 200 && result.statusCode < 300 ? 'SUCCESS' : 'RESPONSE ERROR';
            if (String.isNotBlank(result.errorMessage)) {
                log.ErrorMessage__c = result.errorMessage.length() > 131072 ? result.errorMessage.substring(0, 131072) : result.errorMessage;
                log.hasFailed__c = true;
            }
            if (String.isNotBlank(requestBody)) {
                log.RequestBody__c = requestBody.length() > 131072 ? requestBody.substring(0, 131072) : requestBody;
            }
            if (params != null && !params.isEmpty()) {
                log.Params__c = JSON.serialize(params);
            }
            String resBody = result.body != null ? JSON.serialize(result.body) : '';
            if (String.isNotBlank(resBody)) {
                Integer chunkSize = 131072;
                Integer numChunks = (resBody.length() + chunkSize - 1) / chunkSize;
                for (Integer i = 0; i < numChunks && i < 5; i++) {
                    Integer s = i * chunkSize;
                    Integer e = Math.min(s + chunkSize, resBody.length());
                    log.put('ResponseBody' + (i + 1) + '__c', resBody.substring(s, e));
                }
            }
            insert log;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'InboundRestHandler ::: Log insert failed: ' + e.getMessage());
        }
    }
}