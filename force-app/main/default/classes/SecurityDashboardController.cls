/**
 * @Description LWC (SecuritySoarDashboard) 용 Apex 컨트롤러.
 *              관리자용 3-Way 대응 체계 중 "대시보드 수동 컨트롤"을 지원합니다.
 *              보안 대시보드는 TSP 감지 전용으로, 수동/인바운드 조치로만 생성된 AuditLog는 제외합니다.
 */
public with sharing class SecurityDashboardController {

    /** 수동/인바운드 조치 전용 Source. 이 값들은 대시보드 목록에서 제외(감지 전용 뷰) */
    private static final Set<String> ACTION_ONLY_SOURCES = new Set<String>{
        SecurityTypes.SOURCE_MANUAL_OVERRIDE, 
        SecurityTypes.SOURCE_INBOUND_COMMAND, 
        SecurityTypes.SOURCE_LWC_DASHBOARD, 
        SecurityTypes.SOURCE_SYSTEM_ACTION
    };

    /**
     * @description 최근 유입된 TSP 감지 기반 감사 로그만 조회 (수동/팀즈 조치 전용 건 제외)
     */
    @AuraEnabled(cacheable=true)
    public static List<SecurityAuditLog__c> getAuditLogs() {
        return [
            SELECT Id, AuditKey__c, User__c, User__r.Name, PolicyCode__c, Source__c, AlertCount__c, MaxSeverity__c, LastOccurredAt__c
            FROM SecurityAuditLog__c
            WHERE Source__c NOT IN :ACTION_ONLY_SOURCES
            WITH USER_MODE
            ORDER BY LastOccurredAt__c DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description 최근 실행된 보안 액션 로그 조회 (액션 목록 탭용)
     */
    @AuraEnabled(cacheable=true)
    public static List<SecurityActionLog__c> getActionLogs() {
        return [
            SELECT Id, ActionName__c, Status__c, ExecutedAt__c, Is_Sync__c,
                   SecurityAuditLog__r.AuditKey__c, SecurityAuditLog__r.User__r.Name
            FROM SecurityActionLog__c
            WITH USER_MODE
            ORDER BY ExecutedAt__c DESC
            LIMIT 50
        ];
    }

    /**
     * @description 관리자가 LWC에서 수동으로 액션(계정 동결 등)을 트리거할 때 사용
     */
    @AuraEnabled
    public static void executeManualAction(String actionType, String payload) {
        try {
            // LWC 관리자 화면에서도 직접 Action을 실행하지 않고, 권한 상승 패턴(Platform Event)을 통해
            // 시스템 최고 권한(Automated Process)으로 안전하게 위임하여 로깅 FLS 문제와 UI 블로킹을 원천 차단.
            SecurityPrivilegeEscalator.executeAsSystem(actionType, payload);
        } catch (Exception e) {
            throw new AuraHandledException('액션 실행 위임 실패: ' + e.getMessage());
        }
    }
}