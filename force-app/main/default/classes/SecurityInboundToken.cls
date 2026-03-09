/**
 * [보안 액션 → 팀즈 알림 → 인바운드 → 실제 얼리기] 흐름의 보안 검증 유틸
 *
 * @Description 인바운드 URL 변조·재사용 방지. InterfaceTeamsNotifier에서 token 생성, SecurityActionInboundHandler에서 검증.
 *             - generatePayloadToken: 팀즈 카드 URL 생성 시 호출 (eventKey|userId|policyCode|t 서명)
 *             - verifyPayloadToken: 인바운드 수신 시 호출 (만료시간 포함 검증)
 *             - isRequestFromAllowedOrigin: 팀즈(Referer/Origin)에서 온 요청만 허용
 */
public without sharing class SecurityInboundToken {

    private static final String DELIM = '|';
    private static final String CONFIG_DEV_NAME = 'Default';
    /** ValidSeconds__c 미설정 시 기본 유효시간(초) */
    private static final Integer DEFAULT_VALID_SECONDS = 300;

    /**
     * [1단계] 팀즈 카드 "세션 즉시 종료" 버튼에 붙을 암호화 단일 토큰 생성
     *         AES-256-CBC 기반 (ManagedIV 사용)
     * @param action     보안 액션 명령(예: KILL_SESSION)
     * @param eventKey   이벤트 키
     * @param userId     대상 사용자 ID
     * @param policyCode 정책 코드
     * @param timestampSeconds Unix 시간(초). 만료 시간 검증용.
     * @return Base64URL 인코딩된 단일 암호화 문자열
     */
    public static String generateEncryptedToken(String action, String eventKey, String userId, String policyCode, Long timestampSeconds) {
        String secret = getSecret();
        if (String.isBlank(secret)) return '';
        
        Map<String, String> payloadMap = new Map<String, String>{
            'action' => action,
            'eventKey' => eventKey,
            'userId' => userId,
            'policyCode' => policyCode,
            't' => timestampSeconds != null ? String.valueOf(timestampSeconds) : ''
        };
        
        String jsonStr = JSON.serialize(payloadMap);
        Blob data = Blob.valueOf(jsonStr);
        // Secret을 바탕으로 256비트(32바이트) 해시키 생성
        Blob key = Crypto.generateDigest('SHA-256', Blob.valueOf(secret));
        
        Blob encrypted = Crypto.encryptWithManagedIV('AES256', key, data);
        return EncodingUtil.base64Encode(encrypted).replace('+', '-').replace('/', '_').replaceAll('=+$', '');
    }

    /**
     * [2단계] 인바운드 수신 시 단일 토큰을 복호화하고 내부 시간(t)의 만료 여부를 검증
     * @return 검증 성공 시 복원된 Map, 실패 시 null
     */
    public static Map<String, String> decryptAndVerifyToken(String token) {
        if (String.isBlank(token)) return null;
        
        String secret = getSecret();
        if (String.isBlank(secret)) {
            System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: Secret not configured. Rejecting.');
            return null;
        }
        
        try {
            // URL Safe Base64 복원
            String base64Token = token.replace('-', '+').replace('_', '/');
            while (Math.mod(base64Token.length(), 4) != 0) {
                base64Token += '=';
            }
            
            Blob encrypted = EncodingUtil.base64Decode(base64Token);
            Blob key = Crypto.generateDigest('SHA-256', Blob.valueOf(secret));
            
            Blob decrypted = Crypto.decryptWithManagedIV('AES256', key, encrypted);
            String jsonStr = decrypted.toString();
            
            Map<String, String> payloadMap = (Map<String, String>) JSON.deserialize(jsonStr, Map<String, String>.class);
            
            // 만료 시간 검증
            String tStr = payloadMap.get('t');
            if (String.isBlank(tStr)) return null;
            
            Long ts = Long.valueOf(tStr);
            Integer validSeconds = getValidSeconds();
            Long nowSeconds = System.currentTimeMillis() / 1000;
            
            if (ts < nowSeconds - validSeconds || ts > nowSeconds + 60) {
                System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: Token expired. t=' + tStr);
                return null;
            }
            
            return payloadMap;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: Decryption or verification failed: ' + e.getMessage());
            return null;
        }
    }

    @TestVisible
    private static String getSecret() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            if (config == null) return null;
            String val = config.Secret__c;
            return String.isNotBlank(val) ? val.trim() : null;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: getSecret failed: ' + e.getMessage());
            return null;
        }
    }

    @TestVisible
    private static Integer getValidSeconds() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            if (config == null || config.ValidSeconds__c == null) return DEFAULT_VALID_SECONDS;
            Integer v = config.ValidSeconds__c.intValue();
            return v > 0 ? v : DEFAULT_VALID_SECONDS;
        } catch (Exception e) {
            return DEFAULT_VALID_SECONDS;
        }
    }

    /**
     * [2단계] SecurityActionInboundHandler에서 호출. 팀즈 외(직접 URL 입력 등) 차단.
     *         Referer/Origin 헤더 호스트가 AllowedRefererHosts__c 목록에 있어야 함.
     * @param req RestContext.request (null이면 false)
     * @return 허용 목록이 비어 있으면 검사 생략(true), 목록이 있으면 Referer/Origin 호스트가 목록에 있을 때만 true
     */
    public static Boolean isRequestFromAllowedOrigin(RestRequest req) {
        if (req == null || req.headers == null) return false;
        String referer = req.headers.get('Referer');
        if (String.isBlank(referer)) referer = req.headers.get('referer');
        if (String.isBlank(referer)) {
            referer = req.headers.get('Origin');
            if (String.isBlank(referer)) referer = req.headers.get('origin');
        }
        System.debug('referer ::: ' + referer);
        return isRefererHostAllowed(referer);
    }

    /**
     * Referer/Origin URL 문자열에서 호스트 추출 후 허용 목록과 비교
     */
    @TestVisible
    private static Boolean isRefererHostAllowed(String refererOrOrigin) {
        String allowedCsv = getAllowedRefererHosts();
        if (String.isBlank(allowedCsv)) return true;
        String host = extractHostFromUrl(refererOrOrigin);
        if (String.isBlank(host)) return false;
        String hostLower = host.toLowerCase();
        System.debug('hostLower ::: ' + hostLower);
        for (String allowed : allowedCsv.split(',')) {
            String a = allowed != null ? allowed.trim().toLowerCase() : '';
            if (String.isBlank(a)) continue;
            if (hostLower == a || hostLower.endsWith('.' + a)) return true;
        }
        return false;
    }

    private static String extractHostFromUrl(String url) {
        if (String.isBlank(url)) return null;
        String u = url.trim();
        Integer start = -1;
        if (u.startsWith('https://')) start = 8;
        else if (u.startsWith('http://')) start = 7;
        if (start < 0) return null;
        String afterScheme = u.substring(start);
        Integer slash = afterScheme.indexOf('/');
        String hostPort = slash > 0 ? afterScheme.substring(0, slash) : afterScheme;
        Integer colon = hostPort.indexOf(':');
        return colon > 0 ? hostPort.substring(0, colon) : hostPort;
    }

    /**
     * [Webhook Signature] POST 본문에 대한 HMAC-SHA256 서명 검증.
     * X-Webhook-Signature: sha256=<base64(hmac-sha256(body, secret))> 형식.
     * EnableWebhookSignature__c가 false면 검증 생략(null 반환).
     * @return 검증 실패 시 에러 메시지, 성공 시 null
     */
    public static String verifyWebhookSignature(String requestBody, RestRequest req) {
        if (!isWebhookSignatureEnabled()) return null;
        if (req == null || req.headers == null) return 'Webhook signature required';
        String sigHeader = req.headers.get('X-Webhook-Signature');
        if (String.isBlank(sigHeader)) sigHeader = req.headers.get('x-webhook-signature');
        if (String.isBlank(sigHeader)) return 'Missing X-Webhook-Signature header';
        String secret = getSecret();
        if (String.isBlank(secret)) return 'Webhook signature not configured';
        try {
            Blob mac = Crypto.generateMac('HmacSHA256', Blob.valueOf(requestBody), Blob.valueOf(secret));
            String expected = 'sha256=' + EncodingUtil.base64Encode(mac);
            if (!expected.equals(sigHeader.trim())) return 'Invalid webhook signature';
            return null;
        } catch (Exception e) {
            return 'Signature verification failed: ' + e.getMessage();
        }
    }

    @TestVisible
    private static Boolean isWebhookSignatureEnabled() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            return config != null && config.EnableWebhookSignature__c == true;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * [JTI] 토큰이 이미 사용되었는지 확인. 사용된 토큰은 재사용 불가.
     * @param eventKey 이벤트 키
     * @param tokenTimestamp t 파라미터(Unix 초)
     * @param actionType 액션 종류(예: 'KILL_SESSION', 'FREEZE_USER')
     * @return 이미 사용됐으면 true
     */
    public static Boolean isTokenUsed(String eventKey, Long tokenTimestamp, String actionType) {
        if (String.isBlank(eventKey) || tokenTimestamp == null || String.isBlank(actionType)) return false;
        try {
            List<SecurityInboundTokenUsed__c> used = [
                SELECT Id FROM SecurityInboundTokenUsed__c
                WHERE EventKey__c = :eventKey 
                  AND TokenTimestamp__c = :tokenTimestamp 
                  AND ActionType__c = :actionType
                LIMIT 1
            ];
            return !used.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: isTokenUsed failed: ' + e.getMessage());
            return true; // 오류 시 안전하게 차단
        }
    }

    /**
     * [JTI] 토큰 사용 처리. 액션 실행 직전에 호출하여 재사용 방지.
     */
    public static void markTokenUsed(String eventKey, Long tokenTimestamp, String actionType) {
        if (String.isBlank(eventKey) || tokenTimestamp == null || String.isBlank(actionType)) return;
        try {
            insert new SecurityInboundTokenUsed__c(
                EventKey__c = eventKey,
                TokenTimestamp__c = tokenTimestamp,
                ActionType__c = actionType,
                UsedAt__c = System.now()
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityInboundToken ::: markTokenUsed failed: ' + e.getMessage());
        }
    }

    @TestVisible
    private static String getAllowedRefererHosts() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            if (config == null) return null;
            String val = config.AllowedRefererHosts__c;
            return String.isNotBlank(val) ? val.trim() : null;
        } catch (Exception e) {
            return null;
        }
    }
}