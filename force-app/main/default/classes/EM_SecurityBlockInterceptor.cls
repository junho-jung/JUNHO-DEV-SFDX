/**
* @Author            : jh.jung
* @Description 		 : 고위험군 활동 탐지 및 즉각 차단 인터셉터
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-04      jh.jung           Created
*/
global with sharing class EM_SecurityBlockInterceptor extends SecurityBaseInterceptor {
    private final Decimal MAX_RECORD = 100;

    global override InterceptorResult doEvaluate(SObject event, User user) {
        // [Scenario 5] 해커의 권한 상승 시도 탐지 (Privilege Escalation)
        // 일반 사용자가 시스템 권한 관련 오브젝트를 쿼리할 때 (즉각 차단 & 동결 용도)
        if (event instanceof ApiEvent && !SecurityGuard.isAdmin(user)) {
            String query = (String)event.get('Query');
            if (SecurityGuard.isPrivilegeEscalation(query)) {
                return new InterceptorResult('PRIVILEGE_ESCALATION', 'CRITICAL');
            }
        }

        // [Scenario 6] 해외/미승인 IP 접근 (The Foreign Intruder)
        if (event instanceof ApiEvent) {
            String ip = (String)event.get('SourceIP');
            if (SecurityGuard.isSuspiciousIP(ip)) {
                return new InterceptorResult('SUSPICIOUS_IP_ACCESS', 'CRITICAL');
            }
        }

        // [Scenario 7] 대량 데이터 파괴 시도 (The Saboteur)
        if (event instanceof ApiEvent) {
            if (SecurityGuard.isMassDeletion(event)) {
                return new InterceptorResult('MASS_DATA_DELETION', 'CRITICAL');
            }
        }

        // [Scenario 8] 주말의 유령 (The Weekend Ghost)
        if (event instanceof ReportEvent) {
            if (SecurityGuard.isWeekend()) {
                return new InterceptorResult('WEEKEND_REPORT_ACCESS', 'HIGH');
            }
        }

        // [Scenario 3] 대량 데이터 엑스포트 유출 (Mass Data Leakage)
        // 보고서 엑스포트 1000건 이상 시도 시 (즉시 차단 및 세션 킬 용도)
        if (event instanceof ReportEvent) {
            if (SecurityGuard.isMassExport(event)) {
                return new InterceptorResult('MASS_DATA_EXPORT', 'CRITICAL');
            }
        }

        // [Scenario 1] 심야의 데이터 탈취 (The Midnight Data Heist)
        // 영업사원 등이 심야에 100건 이상의 데이터 조회 시도 시 (동적 Smart Block 용도)
        if (event instanceof ApiEvent) {
            Decimal rows = (Decimal)event.get('RowsProcessed');
            if (rows > MAX_RECORD && SecurityGuard.isOffHours()) {
                // 심야 API 대량 조회
                // 1~2회는 기록/경고, 3회 시 차단하도록 메타데이터 Threshold 활용 예정
                return new InterceptorResult('NIGHT_API_HEIST', 'HIGH');
            }
        }

        return null;
    }
}