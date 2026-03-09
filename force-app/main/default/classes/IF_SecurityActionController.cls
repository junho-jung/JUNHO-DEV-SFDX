/**
 * [보안 액션 → 팀즈 알림 → 인바운드 → 실제 얼리기] 흐름 중 [2단계: 인바운드 진입점]
 *
 * @Description 팀즈 카드 "세션 즉시 종료" 버튼 클릭 시 호출되는 REST 엔드포인트.
 *              Site(Guest)에 노출하여 로그인 없이 호출 가능. InboundRestHandler로 로깅·응답 공통 처리.
 *              GET: action, userId, eventKey, policyCode, t, token (쿼리 파라미터)
 *              POST: 동일 필드를 JSON Body로
 * @urlMapping /services/apexrest/api/security/action
 */
@RestResource(urlMapping='/api/security/action')
global without sharing class IF_SecurityActionController {

    /** 팀즈 링크 클릭 시 브라우저가 GET 요청 */
    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        SecuritySoarTrace.log('IF_SecurityActionController.doGet', new Map<String, Object>{
            'requestUri' => req != null ? req.requestURI : null
        });
        InboundRestHandler.run(req, res, 'SecurityAction', new SecurityActionInboundHandler());
    }

    /** 서버 간 호출 등에서 POST 사용 */
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        SecuritySoarTrace.log('IF_SecurityActionController.doPost', new Map<String, Object>{
            'requestUri' => req != null ? req.requestURI : null
        });
        InboundRestHandler.run(req, res, 'SecurityAction', new SecurityActionInboundHandler());
    }
}