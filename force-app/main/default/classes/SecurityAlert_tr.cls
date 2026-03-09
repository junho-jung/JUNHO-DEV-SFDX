/**
* @Author            : jh.jung
* @Description 		 : SecurityAlert__e 플랫폼 이벤트 트리거 핸들러
* 이벤트 유입 시 중복 이벤트를 필터링하고 실제 비즈니스 로직(Handler)으로 전달함.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-29      jh.jung           Created
*/
public class SecurityAlert_tr extends TriggerHandler {

    /**
     * @description 플랫폼 이벤트는 After Insert만 지원함.
     * 유입된 이벤트 배치를 정제하여 Handler로 위임.
     */
    public override void afterInsert() {
        System.debug('SecurityAlert_tr ::: afterInsert [Start]');

        // 1. 유효성 검사 및 중복 제거 (Deduplication)
        List<SecurityAlert__e> filteredAlerts = filterValidAlerts((List<SecurityAlert__e>)Trigger.new);

        // 2. 비즈니스 로직 핸들러 호출
        if (!filteredAlerts.isEmpty()) {
            System.debug('SecurityAlert_tr ::: Passing ' + filteredAlerts.size() + ' events to Handler');
            SecurityAlertHandler.processAlerts(filteredAlerts);
        }

        System.debug('SecurityAlert_tr ::: afterInsert [End]');
    }

    /**
     * @description 이벤트 배치 내에서 동일한 EventKey__c를 가진 중복 건을 필터링함.
     * 플랫폼 이벤트 특성상 재발행되거나 짧은 시간에 중복 유입될 수 있음을 고려.
     * @param rawEvents Trigger.new 목록
     * @return List<SecurityAlert__e> 필터링된 결과물
     */
    private List<SecurityAlert__e> filterValidAlerts(List<SecurityAlert__e> rawEvents) {
        Set<String> uniqueKeys = new Set<String>();
        List<SecurityAlert__e> results = new List<SecurityAlert__e>();

        for (SecurityAlert__e alert : rawEvents) {
            String eventKey = alert.EventKey__c;

            // Key가 없는 경우: 필터링하지 않고 처리 (예외 상황 대비)
            if (String.isBlank(eventKey)) {
                results.add(alert);
                continue;
            }

            // Key가 중복된 경우: 첫 번째 이벤트만 수용
            if (!uniqueKeys.contains(eventKey)) {
                uniqueKeys.add(eventKey);
                results.add(alert);
            } else {
                // 추후 트러블슈팅을 위해 중복 건 로그 남김
                System.debug('SecurityAlert_tr ::: Duplicate Key Skipped: ' + eventKey);
            }
        }
        return results;
    }
}