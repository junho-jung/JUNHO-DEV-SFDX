/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-05      jh.jung           Created
*/
global with sharing class EM_SecurityMonitorInterceptor extends SecurityBaseInterceptor {

    global override InterceptorResult doEvaluate(SObject event, User user) {

        // [Scenario 10] 유출된 토큰 재사용 (Zombie Token)
        if (event instanceof ApiEvent) {
            Id userId = user != null ? user.Id : null;
            if (SecurityGuard.isStaleToken(userId)) {
                return new InterceptorResult('STALE_TOKEN_USAGE', 'LOW');
            }
        }

        // [Scenario 4] 은밀한 문서 호더 (The Hoarder)
        // 회사 내 주요 시스템에서 잦은 파일/문서를 뷰어하거나 다운로드 하는 행위 (섀도우 모니터링)
        if (SecurityGuard.isFileDownload(event)) {
            // 차단 없이 카운트만 수집 (LOW)
            return new InterceptorResult('FILE_HOARDER', 'LOW');
        }

        // 부가 모니터링 1: 일반 보고서 잦은 열람
        if (event instanceof ReportEvent) {
            // 데모 연출: 사용자는 전혀 차단당하지 않고 자연스럽게 보고서를 보지만
            // 대시보드엔 이 조회 기록이 차곡차곡 쌓임
            return new InterceptorResult('REPORT_MONITORING', 'LOW');
        }

        // 부가 모니터링 2: 일반 데이터 조회 (소량)
        if (event instanceof ApiEvent) {
            String query = (String)event.get('Query');
            if (SecurityGuard.containsSensitiveObject(query)) {
                return new InterceptorResult('SENSITIVE_DATA_VIEW', 'LOW');
            }
        }

        return null; // 모니터링 인터셉터는 언제나 null을 리턴하여 native Block이 발생하지 않거나,
                     // BaseInterceptor의 Smart Block이 발동하지 않을 수준(LOW)을 유지함.
    }
}