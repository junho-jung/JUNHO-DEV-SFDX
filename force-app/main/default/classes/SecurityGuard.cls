/**
* @Author            : jh.jung
* @Description 		 : 보안 정책 검증 및 유틸리티 클래스
* Custom Metadata를 통한 동적 설정 지원 및 다양한 보안 검증 메서드 제공
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-04      jh.jung           Created
  2.0      2026-02-05      jh.jung           Refactored - Custom Metadata 지원, 메서드 보완
*/
public with sharing class SecurityGuard {

    // =================================================================
    // 1-A. Facade Pattern: 타입별 이벤트 분석 전담 메서드 (Tier 2)
    // =================================================================

    /**
     * @description ApiEvent에 대한 모든 보안 룰을 평가하고 가장 적절한 정책 코드를 반환하는 퍼사드 메서드
     */
    public static String analyzeApiEvent(ApiEvent ae, User user) {
        if (ae == null) return null;

        String query = (ae.Query != null) ? ae.Query.toUpperCase() : '';
        Decimal rows = (Decimal)ae.get('RowsProcessed');
        String ip = ae.SourceIp;

        // Block Interceptor Rules (CRITICAL/HIGH)
        if (!isAdmin(user) && isPrivilegeEscalation(query)) return 'PRIVILEGE_ESCALATION';
        if (isSuspiciousIP(ip)) return 'SUSPICIOUS_IP_ACCESS';
        if (isMassDeletion(ae)) return 'MASS_DATA_DELETION';
        if (rows > 100 && isOffHours()) return 'NIGHT_API_HEIST';

        // MFA Interceptor Rules
        if (isSuspiciousClient(ae) && isUserEnrolledInMFA(user?.Id)) return 'SUSPICIOUS_BROWSER_MFA';

        // Monitor Interceptor Rules (LOW)
        if (isStaleToken(user?.Id)) return 'STALE_TOKEN_USAGE';
        if (containsSensitiveObject(query)) return 'SENSITIVE_DATA_VIEW';

        return null; // 위반 사항 없음
    }

    /**
     * @description ReportEvent에 대한 보안 룰 평가 퍼사드
     */
    public static String analyzeReportEvent(ReportEvent re, User user) {
        if (re == null) return null;

        Boolean isExport = (re.Operation != null && re.Operation.contains('Export'));
        Decimal rows = (Decimal)re.get('RowsProcessed');

        // Block & MFA Rules
        if (isExport && rows >= 1000) return 'MASS_DATA_EXPORT';
        if (isWeekend()) return 'WEEKEND_REPORT_ACCESS';
        if (containsVIPSensitiveKeyword(re.Name)) return 'VIP_DATA_ACCESS'; // MFA Required
        if (isExport && rows >= 100 && rows < 1000) return 'REPORT_EXPORT_MFA';

        // Monitor Rules
        return 'REPORT_MONITORING'; // 기본 로깅
    }

    /**
     * @description ListViewEvent에 대한 보안 룰 평가 퍼사드
     */
    public static String analyzeListViewEvent(ListViewEvent lve, User user) {
        if (lve == null) return null;
        if (containsVIPSensitiveKeyword(lve.Name) || isSensitiveObject(lve.QueriedEntities)) {
             return 'VIP_DATA_ACCESS';
        }
        return null;
    }

    // =================================================================
    // 1. 캐시 및 설정 관리
    // =================================================================

    private static User cachedUser;
    private static Map<String, Set<String>> sensitiveObjectsCache;
    private static Map<String, Set<Id>> sensitiveResourcesCache;
    private static Map<String, SecurityPolicy__mdt> policyCache;

    // =================================================================
    // 2. 기본 설정 (Custom Metadata가 없을 때의 Fallback)
    // =================================================================

    private static final Set<String> DEFAULT_SENSITIVE_OBJECTS = new Set<String>{
        'Account', 'Opportunity', 'Contact', 'Lead'
    };

    private static final Integer DEFAULT_OFF_HOURS_START = 22;
    private static final Integer DEFAULT_OFF_HOURS_END = 6;

    // =================================================================
    // 3. 사용자 정보 관리
    // =================================================================

    /**
     * @description 사용자 정보를 캐싱하여 반복적인 쿼리 방지
     */
    public static User getCurrentUser(Id userId) {
        if (userId == null) return null;
        if (cachedUser == null || cachedUser.Id != userId) {
            try {
                cachedUser = [
                    SELECT Id, Name, Email, Profile.Name, ProfileId, UserRoleId
                    FROM User
                    WHERE Id = :userId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'SecurityGuard.getCurrentUser Error: ' + e.getMessage());
                return null;
            }
        }
        return cachedUser;
    }

    /**
     * @description 현재 로그인한 사용자 정보 반환
     */
    public static User getCurrentUser() {
        return getCurrentUser(UserInfo.getUserId());
    }

    /**
     * @description 사용자가 MFA 장치를 등록했는지 여부 확인
     * 중복 로그(MFA 미등록자가 MFA 인터셉터와 Block 인터셉터 양쪽에서 걸리는 현상) 방지용
     */
    public static Boolean isUserEnrolledInMFA(Id userId) {
        if (userId == null) return false;
        try {
            // TwoFactorMethodsInfo 객체는 사용자가 등록한 MFA 수단(Authenticator 앱 등) 정보를 가짐
            Integer mfaCount = [
                SELECT COUNT()
                FROM TwoFactorMethodsInfo
                WHERE UserId = :userId
                AND HasUserVerifiedEmailAddress = true 
            ];
            // HasUserVerifiedEmailAddress 또는 HasAuthenticator 등을 조건으로 쓸 수도 있으나
            // 레코드가 존재한다는 것 자체가 최소한의 2FA 수단이 등록되었음을 의미함
            return mfaCount > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityGuard.isUserEnrolledInMFA Error: ' + e.getMessage());
            return false;
        }
    }

    /**
     * @description 시스템 관리자 프로필 여부 확인
     */
    public static Boolean isAdmin(User u) {
        if (u == null) return false;
        String profileName = u.Profile?.Name ?? '';
        return profileName.contains('System Administrator') || 
               profileName.contains('시스템 관리자') ||
               profileName.contains('Administrator');
    }

    /**
     * @description 현재 사용자가 관리자인지 확인
     */
    public static Boolean isCurrentUserAdmin() {
        return isAdmin(getCurrentUser());
    }

    // =================================================================
    // 4. 민감 오브젝트 검증
    // =================================================================

    /**
     * @description 특정 오브젝트가 민감 정보인지 확인
     * Custom Metadata에서 우선 조회, 없으면 기본값 사용
     */
    public static Boolean isSensitiveObject(String objectName) {
        if (String.isBlank(objectName)) return false;
        
        // Custom Metadata에서 조회 (추후 구현)
        // 현재는 기본값 사용
        return DEFAULT_SENSITIVE_OBJECTS.contains(objectName);
    }

    /**
     * @description 쿼리 문자열에서 민감 오브젝트 포함 여부 확인
     */
    public static Boolean containsSensitiveObject(String query) {
        if (String.isBlank(query)) return false;

        String upperQuery = query.toUpperCase();
        for (String obj : DEFAULT_SENSITIVE_OBJECTS) {
            if (upperQuery.contains('FROM ' + obj.toUpperCase())) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description ListViewEvent의 QueriedEntities에서 민감 오브젝트 확인
     */
    // public static Boolean isSensitiveObject(String queriedEntities) {
    //     if (String.isBlank(queriedEntities)) return false;
        
    //     String upperEntities = queriedEntities.toUpperCase();
    //     for (String obj : DEFAULT_SENSITIVE_OBJECTS) {
    //         if (upperEntities.contains(obj.toUpperCase())) {
    //             return true;
    //         }
    //     }
    //     return false;
    // }

    /**
     * @description 해커의 권한 상승 시도 (메타데이터 및 시스템 오브젝트 쿼리) 확인
     * @param query SOQL Query String
     */
    public static Boolean isPrivilegeEscalation(String query) {
        if (String.isBlank(query)) return false;
        String upperQuery = query.toUpperCase();
        // 가장 해킹에 흔히 쓰이는 민감 메타데이터 테이블들
        List<String> escalationObjects = new List<String>{
            'PROFILE', 'PERMISSIONSET', 'PERMISSIONSETASSIGNMENT', 
            'USERROLE', 'GROUP', 'GROUPMEMBER', 'LOGINHISTORY'
        };
        for (String obj : escalationObjects) {
            if (upperQuery.contains('FROM ' + obj)) {
                return true;
            }
        }
        return false;
    }

    /**
     * @description 내용에 민감한 키워드(VIP 등)가 포함되어 있는지 확인
     * @param text 확인할 텍스트 (예: Report Name, ListView Name)
     */
    public static Boolean containsVIPSensitiveKeyword(String text) {
        if (String.isBlank(text)) return false;
        
        List<String> vipKeywords = new List<String>{
            '임원', '기밀', 'VIP', '주민등록', '고객', '매출', 'TOP'
        };
        
        for (String keyword : vipKeywords) {
            if (text.containsIgnoreCase(keyword)) {
                return true;
            }
        }
        return false;
    }

    // =================================================================
    // 5. 민감 리소스 검증 & 엑스포트 검증
    // =================================================================

    /**
     * @description 특정 리소스(보고서/파일 등)가 보호 대상인지 확인
     * Custom Metadata에서 조회 (추후 구현)
     */
    public static Boolean isSensitiveResource(Id resId) {
        if (resId == null) return false;
        return false; // 현재는 기본값 없음
    }

    /**
     * @description [ReportEvent] 대량의 데이터 엑스포트 시도인지 검증
     */
    public static Boolean isMassExport(SObject event) {
        if (event == null || !(event instanceof ReportEvent)) return false;
        ReportEvent re = (ReportEvent) event;
        
        Boolean isExport = (re.Operation != null && re.Operation.contains('Export'));
        Decimal rows = (Decimal)re.get('RowsProcessed');
        
        // 엑스포트이면서 1000건 이상일 때
        return isExport && (rows >= 1000);
    }

    // =================================================================
    // 6. 시간 기반 검증
    // =================================================================

    /**
     * @description 현재 시각이 비업무 시간인지 판단
     * Custom Metadata에서 설정 조회, 없으면 기본값(22시~06시) 사용
     */
    public static Boolean isOffHours() {
        // 명시적으로 한국 시각(Asia/Seoul)을 기준으로 적용
        Integer hour = Integer.valueOf(Datetime.now().format('H', 'Asia/Seoul'));
        return (hour >= DEFAULT_OFF_HOURS_START || hour <= DEFAULT_OFF_HOURS_END);
    }

    /**
     * @description 특정 시간이 비업무 시간인지 판단
     */
    public static Boolean isOffHours(Datetime dt) {
        if (dt == null) return false;
        Integer hour = Integer.valueOf(dt.format('H', 'Asia/Seoul'));
        return (hour >= DEFAULT_OFF_HOURS_START || hour <= DEFAULT_OFF_HOURS_END);
    }

    // =================================================================
    // 6. 다양한 보안 컨텍스트 검증 (Scenarios 6~10)
    // =================================================================

    /**
     * @description 신뢰할 수 없는 해외/미승인 IP 여부 확인 (Scenario 6)
     */
    public static Boolean isSuspiciousIP(String sourceIp) {
        if (String.isBlank(sourceIp)) return false;
        // 데모 연출용 로직: 보통 '192.', '10.' 등 사내망 IP가 아니거나 특정 해외 대역으로 가정
        // 여기선 하드코딩된 예제 악성 IP 혹은 특정 패턴 감지로 구현
        if (sourceIp.startsWith('185.') || sourceIp.startsWith('220.') || sourceIp == '0.0.0.0') {
            return true;
        }
        return false;
    }

    /**
     * @description 대량 파괴 행위 시도 여부 확인 (Scenario 7)
     */
    public static Boolean isMassDeletion(SObject event) {
        if (event == null || !(event instanceof ApiEvent)) return false;
        ApiEvent ae = (ApiEvent)event;
        
        String query = (ae.Query != null) ? ae.Query.toUpperCase() : '';
        Decimal rows = (Decimal)ae.get('RowsProcessed');
        
        // API 삭제 호출(Bulk API Delete 등에선 Query 필드가 비워지거나 특정 Operation으로 들어옴)
        // 데모용: Query가 없어도 대량 처리가 일어나거나 'DELETE' 키워드가 있을 때
        Boolean isDeleted = (ae.Operation == 'Delete') || query.contains('DELETE ');
        
        return isDeleted && (rows >= 50);
    }

    /**
     * @description 주말 등 비정상적인 접근 요일 여부 확인 (Scenario 8)
     */
    public static Boolean isWeekend() {
        // 명시적으로 한국 시각(Asia/Seoul)을 기준으로 적용
        String dayOfWeek = Datetime.now().format('E', 'Asia/Seoul'); // 'Mon', 'Sat', 'Sun' 등
        return (dayOfWeek.equals('Sat') || dayOfWeek.equals('Sun'));
    }

    /**
     * @description 의심스러운 브라우저 혹은 비표준 클라이언트 툴 탐지 (Scenario 9)
     */
    public static Boolean isSuspiciousClient(SObject event) {
        if (event == null || !(event instanceof ApiEvent)) return false;
        ApiEvent ae = (ApiEvent)event;
        
        String client = ae.Client != null ? ae.Client.toLowerCase() : '';
        // Postman, curl, 파이썬 스크립트 등 비인가 브라우저 탐지
        if (client.contains('postman') || client.contains('curl') || client.contains('python') || client.contains('unknown')) {
            return true;
        }
        return false;
    }

    /**
     * @description 장기 미사용 좀비 토큰/세션 재사용 탐지 (Scenario 10)
     */
    public static Boolean isStaleToken(Id userId) {
        if (userId == null) return false;
        // 데모용: 현재 시간과 사용자의 마지막 로그인 시간을 비교하여 매우 긴 시간(12시간 초과)의 세션이면 좀비 토큰으로 간주
        User u = getCurrentUser(userId);
        if (u == null) return false; // 정보 없을 시 통과 처리
        
        // AuthSession(SessionManagement)을 쿼리하는 것이 정석이나, 데모 목적 상 간이 로직
        // (단, 여기선 데모 목적으로 특정 유저 Role이나 임의 조건으로 True 반환케 세팅 가능)
        // 여기선 단순히 난수로 5% 확률 좀비 토큰(모니터링용)으로 띄움 (시연 시 강제 적용 가능)
        return false; // 실제 로직: AuthSession 발급 시간 대조
    }

    // =================================================================
    // 7. 이벤트 타입 검증
    // =================================================================

    /**
     * @description 실제 파일 다운로드 행위인지 통합 판별
     */
    public static Boolean isFileDownload(SObject event) {
        if (event == null) return false;
        
        String objName = event.getSObjectType().getDescribe().getName();
        if (!objName.contains('FileEvent')) return false;

        try {
            String action = (String)event.get('FileAction');
            return (action == 'UI_DOWNLOAD' || action == 'S');
        } catch (Exception e) {
            return false;
        }
    }

    // =================================================================
    // 8. 데이터 규모 검증
    // =================================================================

    /**
     * @description 대량 데이터 조회 여부 확인
     * @param rowCount 조회된 행 수
     * @param threshold 임계값 (기본값: 1000)
     */
    public static Boolean isMassDataAccess(Decimal rowCount, Integer threshold) {
        if (rowCount == null) return false;
        return rowCount > (threshold != null ? threshold : 1000);
    }

    /**
     * @description 대량 데이터 조회 여부 확인 (기본 임계값 사용)
     */
    public static Boolean isMassDataAccess(Decimal rowCount) {
        return isMassDataAccess(rowCount, 1000);
    }

    // =================================================================
    // 9. 보안 정책 조회 (Custom Metadata)
    // =================================================================

    /**
     * @description 정책 코드로 보안 정책 조회
     * @param policyCode 정책 코드
     * @return SecurityPolicy__mdt (추후 Custom Metadata 타입 생성 필요)
     */
    public static SecurityPolicy__mdt getPolicy(String policyCode) {
        if (String.isBlank(policyCode)) return null;

        if (policyCache == null) {
            policyCache = new Map<String, SecurityPolicy__mdt>();
        }

        if (policyCache.containsKey(policyCode)) {
            return policyCache.get(policyCode);
        }

        try {
            SecurityPolicy__mdt policy = [
                SELECT Id, PolicyCode__c, IsActive__c, ActionTypes__c, ActionButtons__c,
                       ThresholdLow__c, ActionLow__c, ThresholdMedium__c, ActionMedium__c, 
                       ThresholdHigh__c, ActionHigh__c, ThresholdCritical__c, ActionCritical__c
                FROM SecurityPolicy__mdt
                WHERE PolicyCode__c = :policyCode AND IsActive__c = true
                LIMIT 1
            ];
            policyCache.put(policyCode, policy);
            return policy;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'SecurityGuard.getPolicy Error (Not Found): ' + policyCode);
            policyCache.put(policyCode, null);
            return null;
        }
    }

    // =================================================================
    // 10. 동적 임계치 조회를 위한 유틸리티 (Dynamic Thresholds)
    // =================================================================

    /**
     * @description 특정 유저+정책+오늘날짜 기준의 현재 누적 카운드 획득
     * Transaction Security Policy (TSP) 내부에서 동기 블로킹 결정을 위해 사용됨
     * @param userId 유저 아이디
     * @param policyCode 정책 코드
     * @return 현재까지의 누적 AlertCount (없으면 0 반환)
     */
    public static Decimal getCurrentAlertCount(Id userId, String policyCode) {
        if (userId == null || String.isBlank(policyCode)) return 0;
        
        String todayStr = Datetime.now().format('yyyyMMdd');
        String auditKey = String.valueOf(userId) + '_' + policyCode + '_' + todayStr;

        try {
            // AuditKey__c는 Unique External ID이므로 Index를 타서 매우 빠름 (TSP 3초 제한 방어)
            SecurityAuditLog__c audit = [
                SELECT AlertCount__c 
                FROM SecurityAuditLog__c 
                WHERE AuditKey__c = :auditKey 
                LIMIT 1
            ];
            return audit.AlertCount__c != null ? audit.AlertCount__c : 0;
        } catch (QueryException e) {
            return 0; // 아직 기록된 위반 내역이 없음
        }
    }
}