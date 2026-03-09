/**
* @Author            : jh.jung
* @Description 		 : Apex Controller, LWC, Batch, Scheduler 등에서 사용할 수 있는 
* 공통 보안 검증 유틸리티 클래스
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-05      jh.jung           Created
*/
public with sharing class SecurityValidator {

    // =================================================================
    // 1. 기본 검증 메서드
    // =================================================================

    /**
     * @description 현재 사용자의 보안 검증
     * @param context 실행 컨텍스트 ('APEX', 'LWC', 'BATCH', 'SCHEDULER')
     * @param operation 수행할 작업 ('READ', 'CREATE', 'UPDATE', 'DELETE', 'EXPORT')
     * @param resourceType 리소스 타입 ('OBJECT', 'REPORT', 'FILE')
     * @param resourceId 리소스 ID (선택)
     * @return SecurityValidationResult 검증 결과
     */
    public static SecurityValidationResult validate(
        String context,
        String operation,
        String resourceType,
        Id resourceId
    ) {
        SecurityValidationResult result = new SecurityValidationResult();
        result.isValid = true;
        result.context = context;
        result.operation = operation;
        result.resourceType = resourceType;
        result.resourceId = resourceId;

        try {
            User currentUser = SecurityGuard.getCurrentUser();
            if (currentUser == null) {
                result.isValid = false;
                result.errorMessage = 'User not found';
                return result;
            }

            // 1. 관리자 여부 확인 (관리자는 일부 검증 우회 가능)
            Boolean isAdmin = SecurityGuard.isAdmin(currentUser);
            if (isAdmin && shouldBypassForAdmin(context, operation)) {
                result.isValid = true;
                result.bypassed = true;
                result.reason = 'Admin bypass';
                return result;
            }

            // 2. 비업무 시간 검증 (민감 작업의 경우)
            if (isSensitiveOperation(operation) && SecurityGuard.isOffHours()) {
                result.isValid = false;
                result.errorMessage = 'Operation not allowed during off-hours';
                result.severity = 'HIGH';
                result.shouldAlert = true;
                publishSecurityAlert(context, operation, resourceType, resourceId, currentUser, result);
                return result;
            }

            // 3. 리소스 타입별 검증
            if (resourceType == 'OBJECT' && resourceId != null) {
                String objectName = getObjectNameFromId(resourceId);
                if (SecurityGuard.isSensitiveObject(objectName)) {
                    result.isValid = false;
                    result.errorMessage = 'Access to sensitive object not allowed';
                    result.severity = 'CRITICAL';
                    result.shouldAlert = true;
                    publishSecurityAlert(context, operation, resourceType, resourceId, currentUser, result);
                    return result;
                }
            } else if (resourceType == 'REPORT' && resourceId != null) {
                if (SecurityGuard.isSensitiveResource(resourceId)) {
                    result.isValid = false;
                    result.errorMessage = 'Access to sensitive report not allowed';
                    result.severity = 'HIGH';
                    result.shouldAlert = true;
                    publishSecurityAlert(context, operation, resourceType, resourceId, currentUser, result);
                    return result;
                }
            }

            // 4. 컨텍스트별 추가 검증
            if (context == 'BATCH' || context == 'SCHEDULER') {
                // 배치/스케줄러는 추가 검증 필요 (예: 실행 시간, 빈도 등)
                result.warnings = new List<String>{ 'Batch/Scheduler execution detected' };
            }

        } catch (Exception e) {
            result.isValid = false;
            result.errorMessage = 'Validation error: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'SecurityValidator.validate Error: ' + e.getMessage());
        }

        return result;
    }

    /**
     * @description 간소화된 검증 메서드 (리소스 ID 없음)
     */
    public static SecurityValidationResult validate(String context, String operation, String resourceType) {
        return validate(context, operation, resourceType, null);
    }

    /**
     * @description Apex Controller용 검증
     */
    public static SecurityValidationResult validateApex(String operation, String resourceType, Id resourceId) {
        return validate('APEX', operation, resourceType, resourceId);
    }

    /**
     * @description LWC용 검증
     */
    public static SecurityValidationResult validateLWC(String operation, String resourceType, Id resourceId) {
        return validate('LWC', operation, resourceType, resourceId);
    }

    /**
     * @description Batch용 검증
     */
    public static SecurityValidationResult validateBatch(String operation, String resourceType) {
        return validate('BATCH', operation, resourceType, null);
    }

    /**
     * @description Scheduler용 검증
     */
    public static SecurityValidationResult validateScheduler(String operation) {
        return validate('SCHEDULER', operation, 'SYSTEM', null);
    }

    // =================================================================
    // 2. 대량 데이터 조회 검증
    // =================================================================

    /**
     * @description 대량 데이터 조회 전 검증
     * @param rowCount 예상 조회 행 수
     * @param threshold 임계값
     * @return SecurityValidationResult
     */
    public static SecurityValidationResult validateMassDataAccess(Decimal rowCount, Integer threshold) {
        SecurityValidationResult result = new SecurityValidationResult();
        result.isValid = true;
        result.operation = 'READ';
        result.resourceType = 'DATA';

        if (SecurityGuard.isMassDataAccess(rowCount, threshold)) {
            result.isValid = false;
            result.errorMessage = 'Mass data access detected: ' + rowCount + ' rows';
            result.severity = 'CRITICAL';
            result.shouldAlert = true;

            User currentUser = SecurityGuard.getCurrentUser();
            publishSecurityAlert('APEX', 'READ', 'DATA', null, currentUser, result);
        }

        return result;
    }

    // =================================================================
    // 3. 내부 헬퍼 메서드
    // =================================================================

    private static Boolean shouldBypassForAdmin(String context, String operation) {
        // 관리자도 우회할 수 없는 작업들
        Set<String> criticalOperations = new Set<String>{ 'EXPORT', 'DELETE_ALL' };
        return !criticalOperations.contains(operation);
    }

    private static Boolean isSensitiveOperation(String operation) {
        Set<String> sensitiveOps = new Set<String>{ 'DELETE', 'EXPORT', 'MASS_UPDATE' };
        return sensitiveOps.contains(operation);
    }

    private static String getObjectNameFromId(Id recordId) {
        if (recordId == null) return null;
        return recordId.getSObjectType().getDescribe().getName();
    }

    private static void publishSecurityAlert(
        String context,
        String operation,
        String resourceType,
        Id resourceId,
        User user,
        SecurityValidationResult result
    ) {
        if (!result.shouldAlert || user == null) return;

        try {
            String policyCode = context + '_' + operation + '_' + resourceType;
            String severity = result.severity != null ? result.severity : 'MEDIUM';
            String actionType = determineActionType(severity);

            // SecurityAlertPublisher를 통한 플랫폼 이벤트 발행
            // 이벤트 객체 생성 (가상의 이벤트 객체)
            Map<String, Object> eventData = new Map<String, Object>{
                'Context' => context,
                'Operation' => operation,
                'ResourceType' => resourceType,
                'ResourceId' => resourceId != null ? String.valueOf(resourceId) : null,
                'ErrorMessage' => result.errorMessage
            };
            
            // SecurityAlert__e와 유사한 구조의 가상 이벤트 생성
            // 실제로는 SecurityAlert__e 플랫폼 이벤트를 직접 발행하거나
            // SecurityAlertPublisher의 내부 메서드를 활용해야 함
            // 현재는 로깅만 수행 (향후 SecurityAlertPublisher 확장 필요)
            System.debug(LoggingLevel.WARN, 
                'Security Alert: Context=' + context + 
                ', Operation=' + operation + 
                ', ResourceType=' + resourceType +
                ', User=' + user.Name +
                ', Severity=' + severity +
                ', PolicyCode=' + policyCode
            );
            
            // TODO: SecurityAlertPublisher에 validate 컨텍스트용 메서드 추가 필요
            // SecurityAlertPublisher.publishFromValidator(context, policyCode, severity, actionType, eventData, user);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SecurityValidator.publishSecurityAlert Error: ' + e.getMessage());
        }
    }

    private static String determineActionType(String severity) {
        if (severity == 'CRITICAL') return 'KILL_SESSION;NOTIFY_SLACK';
        if (severity == 'HIGH') return 'NOTIFY_SLACK;CREATE_CASE';
        return 'NOTIFY_SLACK';
    }

    // =================================================================
    // 4. 결과 클래스
    // =================================================================

    public class SecurityValidationResult {
        public Boolean isValid { get; set; }
        public Boolean bypassed { get; set; }
        public String context { get; set; }
        public String operation { get; set; }
        public String resourceType { get; set; }
        public Id resourceId { get; set; }
        public String errorMessage { get; set; }
        public String severity { get; set; }
        public Boolean shouldAlert { get; set; }
        public String reason { get; set; }
        public List<String> warnings { get; set; }

        public SecurityValidationResult() {
            this.isValid = true;
            this.bypassed = false;
            this.shouldAlert = false;
            this.warnings = new List<String>();
        }
    }
}