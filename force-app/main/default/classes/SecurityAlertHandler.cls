/**
* @Author            : jh.jung
* @Description 		 : SecurityAlert__e 이벤트를 받아 TSP 로그(SecurityAuditLog__c)를 기록하고,
* 정의된 액션(Case 생성, 알림 등)을 동적 실행하는 핸들러.
* @Target            :
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
  1.1      2026-02-26      jh.jung           Fallback 지원, Kill-Switch, Throttling 추가
*/
public class SecurityAlertHandler {

    /** 플랫폼 이벤트 발행 실패 시 Fallback에서 사용하는 내부 레코드 형태 */
    public class AlertRecord {
        public String EventKey, Source, PolicyCode, Severity, ActionType;
        public String UserId, UserName, ResourceId, ResourceName, ResourceType;
        public String Payload;
    }

    /**
     * @description 유입된 이벤트 리스트를 순회하며 로직 수행
     */
    public static void processAlerts(List<SecurityAlert__e> alerts) {
        SecuritySoarTrace.log('SecurityAlertHandler.processAlerts', new Map<String, Object>{
            'size' => alerts != null ? alerts.size() : 0
        });
        List<AlertRecord> records = new List<AlertRecord>();
        for (SecurityAlert__e a : alerts) {
            records.add(toAlertRecord(a));
        }
        processInternal(records);
    }

    /**
     * @description 플랫폼 이벤트 발행 실패 시 Fallback Queueable에서 호출.
     * @param fallbackJson SecurityAlertPublisher에서 직렬화한 alert 데이터
     */
    public static void processAlertsFromFallback(String fallbackJson) {
        if (String.isBlank(fallbackJson)) return;
        try {
            SecuritySoarTrace.log('SecurityAlertHandler.processAlertsFromFallback', new Map<String, Object>{
                'fallbackJsonLength' => fallbackJson != null ? fallbackJson.length() : 0
            });
            AlertRecord rec = (AlertRecord) JSON.deserialize(fallbackJson, AlertRecord.class);
            processInternal(new List<AlertRecord>{ rec });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'SecurityAlertHandler ::: processAlertsFromFallback failed: ' + e.getStackTraceString());
        }
    }

    private static AlertRecord toAlertRecord(SecurityAlert__e a) {
        AlertRecord r = new AlertRecord();
        r.EventKey = a.EventKey__c;
        r.Source = a.Source__c;
        r.PolicyCode = a.PolicyCode__c;
        r.Severity = a.Severity__c;
        r.ActionType = a.ActionType__c;
        r.UserId = a.UserId__c;
        r.UserName = a.UserName__c;
        r.ResourceId = a.ResourceId__c;
        r.ResourceName = a.ResourceName__c;
        r.ResourceType = a.ResourceType__c;
        r.Payload = a.Payload__c;
        return r;
    }

    private static void processInternal(List<AlertRecord> records) {
        SecuritySoarTrace.log('SecurityAlertHandler.processInternal', new Map<String, Object>{
            'recordCount' => records != null ? records.size() : 0
        });
        if (SecurityKillSwitch.isEnabled() == false) {
            SecuritySoarTrace.log('SecurityAlertHandler.processInternal.KillSwitchOff');
            return;
        }
        Map<String, SecurityAuditLog__c> updatedAudits = processSecurityAudits(records);
        
        String todayStr = Datetime.now().format('yyyyMMdd');
        for (AlertRecord rec : records) {
            String auditKey = rec.UserId + '_' + rec.PolicyCode + '_' + todayStr;
            Decimal currentCount = 1; // Fallback
            if (updatedAudits != null && updatedAudits.containsKey(auditKey)) {
                currentCount = updatedAudits.get(auditKey).AlertCount__c;
            }
            executeActions(rec, currentCount);
        }
    }

    private static void executeActions(AlertRecord alert, Decimal alertCount) {
        SecuritySoarTrace.log('SecurityAlertHandler.executeActions', new Map<String, Object>{
            'eventKey' => alert != null ? alert.EventKey : null,
            'policyCode' => alert != null ? alert.PolicyCode : null,
            'alertCount' => alertCount,
            'severity' => alert != null ? alert.Severity : null
        });

        // 1. 정책 병합 로직 분리 (SecurityPolicyResolver)
        SecurityPolicyResolver.Result policyResult = SecurityPolicyResolver.mergePolicies(alert, alertCount);
        Set<String> finalTypes = policyResult.actionTypes;
        SecurityPolicy__mdt policy = policyResult.policy;

        if (finalTypes == null || finalTypes.isEmpty()) return;

        // 2. 실행 파이프라인 (책임 연쇄 / 필터 체인 통과 확인)
        for (String aType : finalTypes) {
            SecurityTypes.ActionDescriptor actionDesc = SecurityActionFactory.getAction(aType);
            if (actionDesc == null) continue;

            // 서킷 브레이커 및 허용 여부 판별 분리 (SecurityFilterChain)
            if (!SecurityFilterChain.isAllowed(alert, aType, actionDesc)) {
                continue;
            }

            // [ActionButtons__c 주입] 메타데이터에 버튼 설정이 있으면 Payload에 추가함
            String finalPayload = alert.Payload;
            if (policy != null && !String.isBlank(policy.ActionButtons__c) && !String.isBlank(finalPayload)) {
                try {
                    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(finalPayload);
                    payloadMap.put('actionButtons', policy.ActionButtons__c);
                    finalPayload = JSON.serialize(payloadMap);
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'SecurityAlertHandler ::: Failed to inject ActionButtons: ' + e.getMessage());
                }
            }

            // 3. 실제 실행
            SecurityActionExecutor.execute(
                actionDesc.action,
                finalPayload,
                actionDesc.mode
            );
        }
    }

    /**
     * @description 감사 로그(Audit Log) 일괄 Upsert.
     * 동일 Key(User+Policy+Date)를 가진 레코드를 병합하여 DB I/O를 최소화함.
     * @return 갱신된(Upsert 직전 최신 카운트를 담은) SecurityAuditLog__c Map 반환
     */
    private static Map<String, SecurityAuditLog__c> processSecurityAudits(List<AlertRecord> alerts) {
        Map<String, SecurityAuditLog__c> auditMap = new Map<String, SecurityAuditLog__c>();
        String todayStr = Datetime.now().format('yyyyMMdd');

        // Severity 가중치 정의
        Map<String, Integer> severityRank = new Map<String, Integer>{
            'CRITICAL' => 4, 'HIGH' => 3, 'MEDIUM' => 2, 'LOW' => 1
        };

        // 1. 대상 AuditKey 수집 및 맵 초기화 (메모리 상에서 1차 병합)
        for (AlertRecord alert : alerts) {
            String auditKey = alert.UserId + '_' + alert.PolicyCode + '_' + todayStr;
            String currentTimeStr = Datetime.now().format('HH:mm:ss');
            String historyLine = '[' + currentTimeStr + '] ' + alert.ResourceName + ' (' + alert.Severity + ')';

            if (!auditMap.containsKey(auditKey)) {
                auditMap.put(auditKey, new SecurityAuditLog__c(
                    AuditKey__c = auditKey,
                    User__c = alert.UserId,
                    ResourceId__c = alert.ResourceId,
                    ResourceName__c = alert.ResourceName,
                    ResourceType__c = alert.ResourceType,
                    PolicyCode__c = alert.PolicyCode,
                    Source__c = alert.Source,
                    EventKey__c = alert.EventKey,
                    AlertCount__c = 0,
                    OccurrenceHistory__c = '',
                    FirstOccurredAt__c = System.now()
                ));
            }

            // 메모리 상의 병합 로직
            SecurityAuditLog__c audit = auditMap.get(auditKey);
            audit.AlertCount__c += 1;
            audit.LastOccurredAt__c = System.now();
            audit.OccurrenceHistory__c += (String.isBlank(audit.OccurrenceHistory__c) ? '' : '\n') + historyLine;

            // Max Severity 업데이트
            Integer currentMax = severityRank.get(audit.MaxSeverity__c != null ? audit.MaxSeverity__c : 'LOW');
            Integer incoming = severityRank.get(alert.Severity != null ? alert.Severity : 'LOW');
            if (incoming > currentMax || audit.MaxSeverity__c == null) {
                audit.MaxSeverity__c = alert.Severity;
            }
        }

        // 2. 기존 DB 데이터 조회 및 2차 병합 (Bulk Query)
        for (SecurityAuditLog__c existing : [
            SELECT AuditKey__c, AlertCount__c, MaxSeverity__c, FirstOccurredAt__c, OccurrenceHistory__c
            FROM SecurityAuditLog__c
            WHERE AuditKey__c IN :auditMap.keySet()
        ]) {
            SecurityAuditLog__c pending = auditMap.get(existing.AuditKey__c);

            pending.AlertCount__c += existing.AlertCount__c;
            pending.FirstOccurredAt__c = existing.FirstOccurredAt__c;
            pending.OccurrenceHistory__c = existing.OccurrenceHistory__c + '\n' + pending.OccurrenceHistory__c;

            // 기존 데이터와의 Severity 비교
            Integer existingRank = severityRank.get(existing.MaxSeverity__c);
            Integer pendingRank = severityRank.get(pending.MaxSeverity__c);
            if (existingRank > pendingRank) {
                pending.MaxSeverity__c = existing.MaxSeverity__c;
            }
        }

        // 3. 일괄 Upsert 실행
        if (!auditMap.isEmpty()) {
            Database.upsert(auditMap.values(), SecurityAuditLog__c.Fields.AuditKey__c, true);
        }
        
        return auditMap;
    }
}