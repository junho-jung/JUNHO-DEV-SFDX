/**
 * [보안 액션 → 팀즈 알림 → 인바운드 → 실제 얼리기] 흐름 중 [2→3단계: 검증 및 액션 라우팅]
 *
 * 전체 흐름:
 *   [0] 인터셉터 → SecurityAlertPublisher → SecurityAlert__e → SecurityAlertHandler → NOTIFY_TEAMS 액션
 *   [1] InterfaceTeamsNotifier: 팀즈 카드 전송 ("세션 즉시 종료" 버튼 + 인바운드 URL)
 *   [2] 사용자 클릭 → IF_SecurityActionController (GET) → InboundRestHandler → 본 클래스
 *   [3] SecurityInboundAction__mdt 조회 → ISecurityAction.execute() → 계정 동결 등
 *
 * @Description 인바운드 요청을 검증한 뒤 SecurityInboundAction__mdt에 따라 해당 액션 실행.
 *              1) 출처 검사: 팀즈(Referer/Origin)에서 온 요청만 허용
 *              2) 서명+만료시간 검증: 변조·재사용 방지
 *              3) action 파라미터에 따라 해당 액션 실행 → 계정 동결 등
 */
public with sharing class SecurityActionInboundHandler implements IInboundAction {

    /**
     * [2→3단계] 인바운드 비즈니스 로직. 출처 검사 → 파라미터 파싱 → 토큰 검증 → SecurityInboundAction__mdt 기반 액션 실행
     */
    public InboundRestHandler.InboundResult run(String method, String requestBody, Map<String, String> queryParams) {
        SecuritySoarTrace.log('SecurityActionInboundHandler.run.start', new Map<String, Object>{
            'method' => method,
            'hasBody' => String.isNotBlank(requestBody),
            'hasQueryParams' => queryParams != null && !queryParams.isEmpty()
        });
        // [Kill-Switch] 시스템 비활성화 시 503
        if (!SecurityKillSwitch.isEnabled()) {
            return InboundRestHandler.resultError(503, 'Security system temporarily disabled');
        }

        SecuritySoarTrace.log('SecurityActionInboundHandler.run.context', new Map<String, Object>{
            'requestURI' => RestContext.request != null ? RestContext.request.requestURI : null
        });
        
        // 팀즈 외 다른 경로(직접 URL 입력 등) 차단
        if (!SecurityInboundToken.isRequestFromAllowedOrigin(RestContext.request)) {
            return InboundRestHandler.resultError(403, 'Request origin not allowed');
        }
        // [Webhook Signature] POST/PATCH 시 본문 서명 검증 (설정 시)
        if (('POST'.equalsIgnoreCase(method) || 'PATCH'.equalsIgnoreCase(method)) && String.isNotBlank(requestBody)) {
            String sigErr = SecurityInboundToken.verifyWebhookSignature(requestBody, RestContext.request);
            if (sigErr != null) {
                return InboundRestHandler.resultError(401, sigErr);
            }
        }
        String token = null;

        // 1. 단일 토큰 파라미터 획득
        if ('GET'.equalsIgnoreCase(method) && queryParams != null) {
            token = queryParams.get('token');
        } else if (('POST'.equalsIgnoreCase(method) || 'PATCH'.equalsIgnoreCase(method)) && String.isNotBlank(requestBody)) {
            try {
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(requestBody);
                token = (String) body.get('token');
            } catch (Exception e) {
                return InboundRestHandler.resultError(400, 'Invalid JSON body: ' + e.getMessage());
            }
        }

        if (String.isBlank(token)) {
            return InboundRestHandler.resultError(400, 'Missing required parameter: token');
        }

        // 2. 토큰 복호화 및 유효시간/위조 검사
        Map<String, String> decryptedPayload = SecurityInboundToken.decryptAndVerifyToken(token);
        if (decryptedPayload == null) {
            return InboundRestHandler.resultError(403, 'Invalid, missing, or expired encrypted token');
        }

        String action = decryptedPayload.get('action');
        String userId = decryptedPayload.get('userId');
        String eventKey = decryptedPayload.get('eventKey');
        String policyCode = decryptedPayload.get('policyCode');
        String timestampParam = decryptedPayload.get('t');

        if (String.isBlank(action) || String.isBlank(userId)) {
            return InboundRestHandler.resultError(400, 'Corrupted token payload: missing required fields');
        }

        SecurityInboundAction__mdt actionMdt = resolveInboundAction(action);
        if (actionMdt == null) {
            return InboundRestHandler.resultError(400, 'Unsupported action: ' + action);
        }

        if (actionMdt.RequiresToken__c == True) {
            // [JTI] 사용된 토큰 재사용 차단(Replay Attack 방어) - 이종 액션 버튼 동시 허용(JTI 단위 = EventKey + Timestamp + ActionType)
            Long ts = parseTimestamp(timestampParam);
            if (ts != null && SecurityInboundToken.isTokenUsed(eventKey, ts, action)) {
                return InboundRestHandler.resultError(403, 'Token already used (Replay attack prevention)');
            }
            SecurityInboundToken.markTokenUsed(eventKey, ts, action);
        }

        String payloadJson = buildPayloadJson(userId, eventKey, policyCode);
        try {
            // [FIX] 직접 실행 및 콜아웃을 제거하고, SecurityPrivilegeEscalator를 통해 플랫폼 이벤트를 중앙 집중적으로 발행
            SecurityPrivilegeEscalator.executeAsSystem(action.trim().toUpperCase(), payloadJson);

            InboundRestHandler.InboundResult ok = InboundRestHandler.resultOk(new Map<String, Object>{
                'success' => true,
                'action' => action.trim().toUpperCase(),
                'message' => 'Action event published'
            });
            SecuritySoarTrace.log('SecurityActionInboundHandler.run.success', new Map<String, Object>{
                'action' => action != null ? action.trim().toUpperCase() : null,
                'userId' => userId
            });
            return ok;
        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityActionInboundHandler.run.error', new Map<String, Object>{
                'action' => action,
                'userId' => userId,
                'message' => e != null ? e.getMessage() : null
            });
            return InboundRestHandler.resultError(500, e.getMessage());
        }
    }

    private static SecurityInboundAction__mdt resolveInboundAction(String action) {
        if (String.isBlank(action)) return null;
        String key = action.trim().toUpperCase();
        try {
            List<SecurityInboundAction__mdt> rows = [
                SELECT InboundActionType__c, ActionClassName__c, RequiresToken__c
                FROM SecurityInboundAction__mdt
                WHERE InboundActionType__c = :key
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityActionInboundHandler.resolveInboundAction.error', new Map<String, Object>{
                'errorMsg' => e.getMessage()
            });
            return null;
        }
    }

    private static Long parseTimestamp(String timestampParam) {
        if (String.isBlank(timestampParam)) return null;
        try {
            return Long.valueOf(timestampParam.trim());
        } catch (Exception e) {
            return null;
        }
    }

    private static String buildPayloadJson(String userId, String eventKey, String policyCode) {
        Map<String, Object> payload = new Map<String, Object>{
            'userId' => userId,
            'eventKey' => eventKey,
            'policyCode' => policyCode,
            'source' => SecurityTypes.SOURCE_TEAMS_INBOUND // [수정] 상수 사용
        };
        return JSON.serialize(payload);
    }

}