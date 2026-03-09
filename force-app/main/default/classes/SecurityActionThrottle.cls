/**
 * @Description 액션 실행 Throttling. 동일 사용자+정책+액션에 대해 분당 최대 실행 횟수 제한.
 *              SecurityInboundConfig__mdt.ThrottleMaxPerMinute__c (기본 10)
 */
public without sharing class SecurityActionThrottle {

    private static final String CONFIG_DEV_NAME = 'Default';
    private static final Integer DEFAULT_MAX_PER_MINUTE = 10;
    
    private static Map<String, Integer> throttleCache = new Map<String, Integer>();
    private static Boolean isPreloaded = false;

    /**
     * @description 핸들러 루프 전에 호출하여, 처리 대상 이벤트들의 SOQL을 1번의 Bulk 쿼리로 수행합니다.
     */
    public static void preload(Set<String> auditKeys) {
        if (isPreloaded || auditKeys == null || auditKeys.isEmpty()) return;
        
        Datetime windowStart = Datetime.now().addMinutes(-1);
        try {
            for (AggregateResult ar : [
                SELECT SecurityAuditLog__r.AuditKey__c auditKey, ActionName__c actName, COUNT(Id) cnt
                FROM SecurityActionLog__c
                WHERE SecurityAuditLog__r.AuditKey__c IN :auditKeys
                AND ExecutedAt__c >= :windowStart
                GROUP BY SecurityAuditLog__r.AuditKey__c, ActionName__c
            ]) {
                String key = (String)ar.get('auditKey') + '_' + (String)ar.get('actName');
                throttleCache.put(key, (Integer)ar.get('cnt'));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityActionThrottle ::: Preload failed: ' + e.getMessage());
        }
        
        isPreloaded = true;
    }

    /**
     * @return true면 Throttle 초과로 실행 스킵해야 함
     */
    public static Boolean isThrottled(String userId, String policyCode, String actionType) {
        if (String.isBlank(userId) || String.isBlank(actionType)) return false;
        Integer maxPerMinute = getMaxPerMinute();
        if (maxPerMinute <= 0) return false;

        String todayStr = Datetime.now().format('yyyyMMdd');
        String auditKey = userId + '_' + (String.isNotBlank(policyCode) ? policyCode : '') + '_' + todayStr;
        String cacheKey = auditKey + '_' + actionType;

        Integer currentCount = throttleCache.containsKey(cacheKey) ? throttleCache.get(cacheKey) : 0;
        
        // 메모리 상에서 카운트를 지속시켜, 동일 트랜잭션 내 50건이 들어와도 Race condition을 막아줌.
        if (currentCount >= maxPerMinute) {
            return true;
        }
        
        throttleCache.put(cacheKey, currentCount + 1);
        return false;
    }

    private static Integer getMaxPerMinute() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            if (config == null || config.ThrottleMaxPerMinute__c == null) return DEFAULT_MAX_PER_MINUTE;
            return config.ThrottleMaxPerMinute__c.intValue();
        } catch (Exception e) {
            return DEFAULT_MAX_PER_MINUTE;
        }
    }
}