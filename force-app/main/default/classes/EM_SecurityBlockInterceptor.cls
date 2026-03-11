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
        String policyCode = null;
        String severity = 'CRITICAL';

        // 1. ApiEvent Security Rule Analysis
        if (event instanceof ApiEvent) {
            policyCode = SecurityGuard.analyzeApiEvent((ApiEvent)event, user);
            // NIGHT_API_HEIST requires specific severity adjustment based on old rules
            if (policyCode == 'NIGHT_API_HEIST') severity = 'HIGH';
        } 
        // 2. ReportEvent Security Rule Analysis
        else if (event instanceof ReportEvent) {
            policyCode = SecurityGuard.analyzeReportEvent((ReportEvent)event, user);
            if (policyCode == 'WEEKEND_REPORT_ACCESS') severity = 'HIGH';
        }

        // Return Block Result if any Critical/High violation is detected
        if (String.isNotBlank(policyCode) && (severity == 'CRITICAL' || severity == 'HIGH')) {
            // Note: MFA and Monitoring specific rules are filtered out or not returned as Critical/High from Facade directly by context
            if (policyCode == 'PRIVILEGE_ESCALATION' || policyCode == 'SUSPICIOUS_IP_ACCESS' || 
                policyCode == 'MASS_DATA_DELETION' || policyCode == 'MASS_DATA_EXPORT' || 
                policyCode == 'WEEKEND_REPORT_ACCESS' || policyCode == 'NIGHT_API_HEIST') {
                return new InterceptorResult(policyCode, severity);
            }
        }
        
        return null;
    }
}