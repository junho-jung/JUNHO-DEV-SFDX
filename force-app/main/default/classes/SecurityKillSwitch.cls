/**
 * @Description 시스템 Kill-Switch. IsSystemEnabled__c가 false면 SOAR 액션 전면 중단.
 *              SecurityInboundConfig__mdt.Default 또는 전용 메타데이터에서 조회.
 */
public without sharing class SecurityKillSwitch {

    private static final String CONFIG_DEV_NAME = 'Default';

    /**
     * @return true면 정상 운영(액션 실행), false면 비활성화(모든 액션 스킵)
     */
    public static Boolean isEnabled() {
        try {
            SecurityInboundConfig__mdt config = SecurityInboundConfig__mdt.getInstance(CONFIG_DEV_NAME);
            if (config == null) return true;
            return config.IsSystemEnabled__c != false;
        } catch (Exception e) {
            return true;
        }
    }
}