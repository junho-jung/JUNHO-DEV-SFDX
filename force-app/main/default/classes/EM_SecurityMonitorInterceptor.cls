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

        String policyCode = null;

        if (event instanceof ApiEvent) {
            policyCode = SecurityGuard.analyzeApiEvent((ApiEvent)event, user);
        } else if (event instanceof ReportEvent) {
            policyCode = SecurityGuard.analyzeReportEvent((ReportEvent)event, user);
        }

        // [Scenario 4] 은밀한 문서 호더 (The Hoarder) (별도 FileEvent 처리 유지)
        if (SecurityGuard.isFileDownload(event)) {
            policyCode = 'FILE_HOARDER';
        }

        if (policyCode == 'STALE_TOKEN_USAGE' || policyCode == 'FILE_HOARDER' || 
            policyCode == 'REPORT_MONITORING' || policyCode == 'SENSITIVE_DATA_VIEW') {
            return new InterceptorResult(policyCode, 'LOW');
        }

        return null; // 모니터링 인터셉터는 언제나 null을 리턴하거나 LOW 등급만 발행함.
    }
}