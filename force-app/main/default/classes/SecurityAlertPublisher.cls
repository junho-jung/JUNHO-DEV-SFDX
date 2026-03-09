/**
* @Author            : jh.jung
* @Description 		 : 다양한 TxnSecurity 이벤트를 SecurityAlert__e 플랫폼 이벤트로 표준화하여 발행.
* 각 이벤트 타입(Report, API, Login 등)에 맞는 상세 정보를 추출하여 JSON 페이로드로 래핑함.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-04      jh.jung           Created
*/
public with sharing class SecurityAlertPublisher {

    /**
     * @description 보안 경보 이벤트 발행
     * @param source 인터셉터 클래스명
     * @param policyCode 정책 식별 코드 (예: NIGHT_MASS_API)
     * @param severity 위험도 (CRITICAL, HIGH, etc.)
     * @param actionType 수행할 액션 (Factory용 구분값)
     * @param rawEvent TxnSecurity로부터 전달받은 원본 SObject
     * @param user 대상 사용자 정보
     */
    public static void publish(
        String source, String policyCode, String severity, String actionType,
        SObject rawEvent, User user
    ) {
        // [보안 필터] 무한 재귀 방지: 보안 로그 자체에 대한 조회/수정 이벤트는 처리하지 않음
        if (isSecurityLogContext(rawEvent)) return;

        String extractedAction = getActionNameSafely(rawEvent);

        // 1. 공통 페이로드 및 리소스 변수 초기화
        Map<String, Object> payloadMap = initializeBasePayload(user, source, policyCode, severity, extractedAction);
        ResourceInfo res = extractResourceInfo(rawEvent, payloadMap);

        // 3. 중복 방지 지문(Fingerprint) 생성
        // 사용자 + 정책 + 리소스 + 분 단위 시각을 조합하여 동일 배치의 중복 유입 방지
        String timeKey = System.now().format('yyyyMMddHHmm');
        String eventKey = user.Id + ':' + policyCode + ':' + res.id + ':' + timeKey;
        payloadMap.put('eventKey', eventKey);

        SecuritySoarTrace.log('SecurityAlertPublisher.publish', new Map<String, Object>{
            'source' => source,
            'policyCode' => policyCode,
            'severity' => severity,
            'actionType' => actionType,
            'eventKey' => eventKey
        });

        // 4. 플랫폼 이벤트 객체 조립
        SecurityAlert__e alert = new SecurityAlert__e(
            EventKey__c     = eventKey,
            Source__c       = source,
            PolicyCode__c   = policyCode,
            Severity__c     = severity,
            ActionType__c   = actionType,
            UserId__c       = user.Id,
            UserName__c     = user.Name,
            ResourceId__c   = res.id,
            ResourceName__c = res.name,
            ResourceType__c = res.type,
            Payload__c      = JSON.serialize(payloadMap)
        );

        // 5. 발행 및 결과 처리 (실패 시 Fallback Queueable)
        emitEvent(alert);
    }

    /**
     * @description Fallback용 AlertRecord JSON 생성. emitEvent 실패 시 Queueable에 전달.
     */
    @TestVisible
    private static String toFallbackJson(SecurityAlert__e alert) {
        SecurityAlertHandler.AlertRecord rec = new SecurityAlertHandler.AlertRecord();
        rec.EventKey = alert.EventKey__c;
        rec.Source = alert.Source__c;
        rec.PolicyCode = alert.PolicyCode__c;
        rec.Severity = alert.Severity__c;
        rec.ActionType = alert.ActionType__c;
        rec.UserId = alert.UserId__c;
        rec.UserName = alert.UserName__c;
        rec.ResourceId = alert.ResourceId__c;
        rec.ResourceName = alert.ResourceName__c;
        rec.ResourceType = alert.ResourceType__c;
        rec.Payload = alert.Payload__c;
        return JSON.serialize(rec);
    }

    /**
     * @description 기초 페이로드 생성
     */
    private static Map<String, Object> initializeBasePayload(User u, String src, String code, String sev, String actionName) {
        return new Map<String, Object>{
            'userId'     => u.Id,
            'userName'   => u.Name,
            'userEmail'  => u.Email,
            'profile'    => (u.Profile != null) ? u.Profile.Name : 'N/A',
            'policyCode' => code,
            'severity'   => sev,
            'source'     => src,
            'actionName' => actionName,
            'timestamp'  => System.now().format('yyyy-MM-dd HH:mm:ss')
        };
    }

    /**
     * @description 이벤트 타입별로 리소스 ID, 이름, 타입을 동적으로 추출
     */
    private static ResourceInfo extractResourceInfo(SObject rawEvent, Map<String, Object> payload) {
        ResourceInfo info = new ResourceInfo();

        if (rawEvent instanceof ReportEvent) {
            ReportEvent re = (ReportEvent) rawEvent;
            info.setValues(re.ReportId, getReportName(re.ReportId), 'ReportEvent');
            payload.put('actionName', re.ActionName);
            payload.put('format', re.Format);
        }
        else if (rawEvent instanceof ApiEvent) {
            ApiEvent ae = (ApiEvent) rawEvent;
            info.setValues(ae.LoginHistoryId, ae.Query, 'ApiEvent');
            payload.put('query', ae.Query);
            payload.put('rows', ae.RowsProcessed);
        }
        else if (rawEvent instanceof LoginEvent) {
            LoginEvent le = (LoginEvent) rawEvent;
            info.setValues(le.LoginHistoryId, le.LoginType, 'LoginEvent');
            payload.put('sourceIp', le.SourceIp);
            payload.put('status', le.Status);
        }
        else {
            String objName = rawEvent.getSObjectType().getDescribe().getName();
            info.setValues((String)rawEvent.get('EventIdentifier'), 'Event: ' + objName, objName);
        }

        // 이름이 너무 길 경우(API Query 등) 가독성을 위해 자동 생략 처리 가능
//        if (info.name != null && info.name.length() > 255) {
//            info.name = info.name.substring(0, 252) + ...";
//        }

        return info;
    }

    private static void emitEvent(SecurityAlert__e alert) {
        try {
            Database.SaveResult sr = EventBus.publish(alert);
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug(LoggingLevel.ERROR, '❌ SecurityAlertPublisher Error: ' + err.getMessage());
                }
                enqueueFallback(alert);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, '❌ SecurityAlertPublisher Exception: ' + e.getStackTraceString());
            enqueueFallback(alert);
        }
    }

    private static void enqueueFallback(SecurityAlert__e alert) {
        try {
            String fallbackJson = toFallbackJson(alert);
            System.enqueueJob(new SecurityAlertFallbackJob(fallbackJson));
            System.debug(LoggingLevel.WARN, 'SecurityAlertPublisher ::: Fallback Job enqueued');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SecurityAlertPublisher ::: Fallback enqueue failed: ' + e.getMessage());
        }
    }

    /**
     * @description 보안 감사 로그를 조회하는 쿼리 자체가 이벤트를 발생시키지 않도록 필터링
     */
    private static Boolean isSecurityLogContext(SObject rawEvent) {
        if (rawEvent instanceof ApiEvent) {
            String query = (String)rawEvent.get('Query');
            return String.isNotBlank(query) && query.containsIgnoreCase('SecurityAuditLog__c');
        }
        return false;
    }

    /**
     * @description SObject 필드 맵을 분석하여 안전하게 액션명 추출
     */
    private static String getActionNameSafely(SObject event) {
        // 1. 현재 객체에 채워진 필드 맵 추출 (null 세이프 처리)
        Map<String, Object> eventMap = event?.getPopulatedFieldsAsMap();
        if (eventMap == null) return 'UNKNOWN';

        // 2. 우선순위에 따른 필드 체이닝
        return String.valueOf(
            eventMap.get('ActionName')     ??  // API, Report 표준
            eventMap.get('ListViewAction') ??  // ListView 표준
            eventMap.get('FileAction')     ??  // File 표준
            eventMap.get('LoginType')      ??  // Login 표준
            eventMap.get('QueriedEntities')??  // ListView 등에서 대상이라도 추출
            eventMap.get('EventSource')    ??  // 최후의 보루 (Lightning 등)
            'UNKNOWN'                          // 진짜 아무것도 없을 때
        );
    }

    private static String getReportName(Id reportId) {
        if (reportId == null) return 'N/A';
        for (Report r : [SELECT Name FROM Report WHERE Id = :reportId LIMIT 1]) return r.Name;
        return 'Unknown Report (' + reportId + ')';
    }

    // 데이터 전달용 내부 클래스
    private class ResourceInfo {
        String id, name, type;
        void setValues(String i, String n, String t) { id = i; name = n; type = t; }
    }
}