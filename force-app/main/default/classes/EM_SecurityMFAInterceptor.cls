/**
* @Author            : jh.jung
* @Description 		 : 특정 조건(파일 다운로드, 보고서 접근, 대량 쿼리) 발생 시
* 추가 인증(MFA)을 요구하고 관련 보안 액션을 트리거함.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-05      jh.jung           Created
*/
global with sharing class EM_SecurityMFAInterceptor extends SecurityBaseInterceptor {

    global override InterceptorResult doEvaluate(SObject event, User user) {
        // [중복 로그 방지] 사용자가 MFA에 등록되어 있지 않다면, 어차피 MFA를 띄워도 의미가 없고
        // Block 인터셉터 등에 룰이 위임되어 있을 확률이 높으므로 이 인터셉터는 조용히 패스함.
        if (user == null || !SecurityGuard.isUserEnrolledInMFA(user.Id)) {
            return null;
        }

        String policyCode = null;

        if (event instanceof ApiEvent) {
            policyCode = SecurityGuard.analyzeApiEvent((ApiEvent)event, user);
        } else if (event instanceof ReportEvent) {
            policyCode = SecurityGuard.analyzeReportEvent((ReportEvent)event, user);
        } else if (event instanceof ListViewEvent) {
            policyCode = SecurityGuard.analyzeListViewEvent((ListViewEvent)event, user);
        }

        if (policyCode == 'SUSPICIOUS_BROWSER_MFA' || policyCode == 'VIP_DATA_ACCESS' || policyCode == 'REPORT_EXPORT_MFA') {
            return new InterceptorResult(policyCode, 'HIGH');
        }

        return null;
    }
}