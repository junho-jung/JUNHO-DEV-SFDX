/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-16      jh.jung           Created
*/
public without sharing class SystemSettingsService {

    /**
     * @description LWC가 실행되는 Host URL을 반환합니다.
     */
    @AuraEnabled(cacheable=true)
    public static String getLwcHostUrl() {
        return URL.getOrgDomainUrl().getHost();
    }

    /**
     * @description Visualforce Host URL을 추론하여 반환합니다. (모든 환경 커버리지 목표)
     * Enhanced Domains (URL.salesforce.com -> URL.visual.force.com) 및
     * 레거시 도메인 규칙 (URL.lightning.force.com -> URL--c.visual.force.com)을 모두 시도합니다.
     * @return Visualforce Host URL (String)
     */
    @AuraEnabled(cacheable=true)
    public static String getVisualforceHostUrl() {

        String lwcHostUrl = SystemSettingsService.getLwcHostUrl();
        String visualforceHost = '';

        // 1. Enhanced Domains 규칙 적용 (가장 최신 표준)
        // *.salesforce.com -> *.visual.force.com 으로 변경하는 것이 핵심
        if (lwcHostUrl.contains('.salesforce.com')) {
            visualforceHost = lwcHostUrl.replace('.salesforce.com', '.visual.force.com');
            System.debug(LoggingLevel.INFO, 'VF Host (Enhanced Rule): ' + visualforceHost);
            return visualforceHost;
        }

        // 2. 레거시 Lightning/Sandbox Domains 규칙 적용 (Enhanced Domain 비활성화 시)
        // *.lightning.force.com -> *.visual.force.com으로 변경 후 VF Subdomain 접미사 추가
        if (lwcHostUrl.contains('.lightning.force.com')) {

            // Host (https://myhost.com) 부분만 추출하여 조작합니다.
            String hostOnly = lwcHostUrl.substring(lwcHostUrl.indexOf('//') + 2);

            // a. Visualforce 도메인으로 변경 (.visual.force.com)
            String baseVfHost = hostOnly.replace('.lightning.force.com', '.visual.force.com');

            // b. VF Subdomain (c.) 추가:
            //    Visualforce 도메인은 보통 --c. 또는 -c.가 붙습니다.
            //    이 규칙은 조직 설정에 따라 다르지만, 가장 일반적인 레거시 형태인 --c를 시도합니다.
            visualforceHost = 'https://' + baseVfHost.replace('.visual.force.com', '--c.visual.force.com');

            System.debug(LoggingLevel.INFO, 'VF Host (Legacy Rule): ' + visualforceHost);
            return visualforceHost;
        }

        // 3. Fallback: 예상치 못한 도메인 구조인 경우, LWC Host를 그대로 반환하거나 에러 처리
        System.debug(LoggingLevel.WARN, 'VF Host (Fallback): Host URL을 추론할 수 없음. LWC Host 반환.');
        return lwcHostUrl; // 안전을 위해 LWC Host를 반환하여 통신 시도를 포기하지 않음
    }

    /**
     * @description 현재 조직이 Sandbox 환경인지 Production 환경인지 여부를 반환합니다.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isSandboxEnvironment() {
        Organization org = [SELECT IsSandbox FROM Organization LIMIT 1];
        return org.IsSandbox;
    }
}