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

        // [Scenario 9] 정체불명의 브라우저 접근 (The Unknown Device)
        if (event instanceof ApiEvent) {
            if (SecurityGuard.isSuspiciousClient(event)) {
                return new InterceptorResult('SUSPICIOUS_BROWSER_MFA', 'HIGH');
            }
        }

        // [Scenario 2] VIP 민감 정보 스니핑 방어 (The VIP Sneak Peek)
        // 리스트뷰 이름이나 보고서 이름에 '기밀', '임원' 등이 포함되어 있을 때 강제 MFA
        if (event instanceof ListViewEvent) {
            ListViewEvent lve = (ListViewEvent) event;
            if (SecurityGuard.containsVIPSensitiveKeyword(lve.Name) || SecurityGuard.isSensitiveObject(lve.QueriedEntities)) {
                return new InterceptorResult('VIP_DATA_ACCESS', 'HIGH'); // MFA 요구
            }
        }

        if (event instanceof ReportEvent) {
            ReportEvent re = (ReportEvent) event;
            if (SecurityGuard.containsVIPSensitiveKeyword(re.Name)) {
                return new InterceptorResult('VIP_DATA_ACCESS', 'HIGH'); // MFA 요구
            }
            
            // 기존 유지 (일반적인 엑스포트는 MFA 요구 - 규모가 작을 경우)
            Decimal rows = (Decimal)re.get('RowsProcessed');
            Boolean isExport = (re.Operation != null && re.Operation.contains('Export'));
            if (isExport && rows >= 100 && rows < 1000) {
                return new InterceptorResult('REPORT_EXPORT_MFA', 'HIGH'); 
            }
        }

        return null;
    }
}