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

    /**
     * @description 정책(SecurityPolicy__mdt)과 이벤트 자체(ActionType__c)를 합쳐 최종 액션 목록을 만든 뒤 실행.
     *              - SecurityPolicy__mdt.ActionTypes__c : 정책에 정의된 기본 액션 목록
     *              - SecurityAlert__e.ActionType__c  : 이벤트에서 추가로 지정한 액션 목록
     */
    private static void executeActions(AlertRecord alert, Decimal alertCount) {
        SecuritySoarTrace.log('SecurityAlertHandler.executeActions', new Map<String, Object>{
            'eventKey' => alert != null ? alert.EventKey : null,
            'policyCode' => alert != null ? alert.PolicyCode : null,
            'alertCount' => alertCount,
            'severity' => alert != null ? alert.Severity : null
        });
        List<String> mergedTypes = new List<String>();

        // 1) 정책 기반 점진적 액션 (PolicyCode__c 기준)
        SecurityPolicy__mdt policy = null;
        if (!String.isBlank(alert.PolicyCode)) {
            try {
                policy = SecurityGuard.getPolicy(alert.PolicyCode);
                if (policy != null) {
                    Boolean matchedDynamic = false;

                    // 점진적 임계치 판별 (높은 단계부터 하향식 판별)
                    if (policy.ThresholdCritical__c != null && alertCount >= policy.ThresholdCritical__c && !String.isBlank(policy.ActionCritical__c)) {
                        mergedTypes.addAll(policy.ActionCritical__c.split(';'));
                        matchedDynamic = true;
                    } else if (policy.ThresholdMedium__c != null && alertCount >= policy.ThresholdMedium__c && !String.isBlank(policy.ActionMedium__c)) {
                        mergedTypes.addAll(policy.ActionMedium__c.split(';'));
                        matchedDynamic = true;
                    } else if (policy.ThresholdLow__c != null && alertCount >= policy.ThresholdLow__c && !String.isBlank(policy.ActionLow__c)) {
                        mergedTypes.addAll(policy.ActionLow__c.split(';'));
                        matchedDynamic = true;
                    }

                    // 일치하는 동적 룰이 없거나 메타데이터에 미지정된 경우, 기본 ActionTypes__c 로 Fallback
                    if (!matchedDynamic && !String.isBlank(policy.ActionTypes__c)) {
                        mergedTypes.addAll(policy.ActionTypes__c.split(';'));
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'SecurityAlertHandler ::: Failed to evaluate SecurityPolicy__mdt logic: ' + e.getMessage());
            }
        }

        // 2) 이벤트 자체에 실린 액션
        if (!String.isBlank(alert.ActionType)) {
            mergedTypes.addAll(alert.ActionType.split(';'));
        }

        // 정리: trim + 중복 제거
        Set<String> finalTypes = new Set<String>();
        for (String t : mergedTypes) {
            String tt = t != null ? t.trim() : null;
            if (!String.isBlank(tt)) {
                finalTypes.add(tt);
            }
        }

        if (finalTypes.isEmpty()) return;

        // 3) [Throttling] 초과 시 액션 스킵
        for (String aType : finalTypes) {
            SecurityTypes.ActionDescriptor actionDesc = SecurityActionFactory.getAction(aType);
            if (actionDesc == null) continue;
            String logActionName = String.valueOf(actionDesc.action).substringBefore(':');
            if (SecurityActionThrottle.isThrottled(alert.UserId, alert.PolicyCode, logActionName)) {
                System.debug(LoggingLevel.WARN, 'SecurityAlertHandler ::: Throttled: ' + aType);
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