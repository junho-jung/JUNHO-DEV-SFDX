/**
* @Author            : jh.jung
* @Description       : SecurityActionRequest__e 플랫폼 이벤트 트리거 핸들러.
*                      LWC 대시보드/인바운드에서 발행된 수동 액션 요청을 수신하여
*                      1) SecurityAuditLog__c 부모를 Bulk Upsert 하고
*                      2) SecurityActionExecutor를 통해 실제 보안 액션을 벌크 실행합니다.
*/
public class SecurityActionRequest_tr extends TriggerHandler {

    /**
     * @description 플랫폼 이벤트는 After Insert만 지원함.
     *              유입된 SecurityActionRequest__e 배치를 정제하여 AuditLog Upsert 후 액션을 실행.
     */
    public override void afterInsert() {
        SecuritySoarTrace.log('SecurityActionRequest_tr.afterInsert.start', new Map<String, Object>{
            'recordCount' => Trigger.new.size()
        });

        List<SecurityActionRequest__e> events = (List<SecurityActionRequest__e>) Trigger.new;
        if (events.isEmpty()) return;

        // 1. AuditLog 일괄 Upsert를 위한 Map 구성 (Bulkify)
        //    수동 제어(LWC)나 외부 명령(Inbound)으로 액션을 바로 때릴 때,
        //    부모 기록(AuditLog)이 없어서 ActionLog가 DML 에러(INVALID_CROSS_REFERENCE_KEY) 나는 것을 방지함.
        Map<String, SecurityAuditLog__c> auditLogsToUpsert = new Map<String, SecurityAuditLog__c>();
        String todayStr = Datetime.now().format('yyyyMMdd');

        for (SecurityActionRequest__e evt : events) {
            if (String.isNotBlank(evt.Payload__c)) {
                try {
                    Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(evt.Payload__c);
                    String userId = (String) payloadMap.get('userId');
                    String policyCode = (String) payloadMap.get('policyCode');
                    String source = (String) payloadMap.get('source');

                    // 정책 코드가 없다면 수동/인바운드로 간주
                    if (String.isBlank(policyCode)) {
                        policyCode = String.isNotBlank(source) && source == SecurityTypes.SOURCE_TEAMS_INBOUND ? SecurityTypes.SOURCE_INBOUND_COMMAND : SecurityTypes.SOURCE_MANUAL_OVERRIDE;
                    }

                    if (String.isNotBlank(userId)) {
                        String auditKey = userId + '_' + policyCode + '_' + todayStr;

                        if (!auditLogsToUpsert.containsKey(auditKey)) {
                            auditLogsToUpsert.put(auditKey, new SecurityAuditLog__c(
                                AuditKey__c = auditKey,
                                User__c = userId,
                                PolicyCode__c = policyCode,
                                Source__c = String.isNotBlank(source) ? source : SecurityTypes.SOURCE_SYSTEM_ACTION,
                                MaxSeverity__c = 'CRITICAL' // 관리자 강제 타격이므로 심각도를 CRITICAL로 올림
                            ));
                        }
                    }
                } catch (Exception e) {
                    SecuritySoarTrace.log('SecurityActionRequest_tr.parsePayload.error', new Map<String, Object>{ 'errorMsg' => e.getMessage() });
                }
            }
        }

        // 2. 기존 AuditLog 조회 후 Source__c 보존 (TSP 감지 건은 수동 조치 시에도 Source 덮어쓰지 않음)
        if (!auditLogsToUpsert.isEmpty()) {
            Set<String> auditKeys = auditLogsToUpsert.keySet();
            for (SecurityAuditLog__c existing : [
                SELECT Id, AuditKey__c, Source__c
                FROM SecurityAuditLog__c
                WHERE AuditKey__c IN :auditKeys
                LIMIT 500
            ]) {
                SecurityAuditLog__c pending = auditLogsToUpsert.get(existing.AuditKey__c);
                if (pending != null && String.isNotBlank(existing.Source__c)) {
                    pending.Source__c = existing.Source__c;
                }
            }
        }

        // 3. AuditLog Upsert 수행 (부모 레코드 강제 생성/업데이트)
        if (!auditLogsToUpsert.isEmpty()) {
            try {
                Database.upsert(auditLogsToUpsert.values(), SecurityAuditLog__c.Fields.AuditKey__c, true);
                SecuritySoarTrace.log('SecurityActionRequest_tr.upsertAuditLogs.success', new Map<String, Object>{ 
                    'upsertedCount' => auditLogsToUpsert.size() 
                });
            } catch (Exception e) {
                SecuritySoarTrace.log('SecurityActionRequest_tr.upsertAuditLogs.error', new Map<String, Object>{ 'errorMsg' => e.getMessage() });
            }
        }

        // 4. 보안 액션 트랜잭션 벌크 처리 (startAsyncContext ~ flushAsyncContext)
        SecurityActionExecutor.startAsyncContext();

        for (SecurityActionRequest__e evt : events) {
            try {
                SecurityTypes.ActionDescriptor descr = SecurityActionFactory.getAction(evt.ActionName__c);
                if (descr != null) {
                    SecurityActionExecutor.execute(descr.action, evt.Payload__c, descr.mode);
                } else {
                    SecuritySoarTrace.log('SecurityActionRequest_tr.executeAction.unknown_action', new Map<String, Object>{ 'actionName' => evt.ActionName__c });
                }
            } catch (Exception e) {
                SecuritySoarTrace.log('SecurityActionRequest_tr.executeAction.error', new Map<String, Object>{ 'errorMsg' => e.getMessage() });
            }
        }

        SecurityActionExecutor.flushAsyncContext();
        
        SecuritySoarTrace.log('SecurityActionRequest_tr.afterInsert.end');
    }
}