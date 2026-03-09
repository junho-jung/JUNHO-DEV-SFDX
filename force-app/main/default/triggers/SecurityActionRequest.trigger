trigger SecurityActionRequest on SecurityActionRequest__e (after insert) {
    System.debug('SecurityActionRequest trigger catch');
    TriggerHandler.runTriggerByCustomMeta(this);
//    // 1. AuditLog 일괄 Upsert를 위한 Map 구성 (Bulkify)
//    // 수동 제어(LWC)나 외부 명령(Inbound)으로 액션을 바로 때릴 때,
//    // 부모 기록(AuditLog)이 없어서 ActionLog가 DML 에러(INVALID_CROSS_REFERENCE_KEY) 나는 것을 방지함.
//    Map<String, SecurityAuditLog__c> auditLogsToUpsert = new Map<String, SecurityAuditLog__c>();
//    String todayStr = Datetime.now().format('yyyyMMdd');
//
//    for (SecurityActionRequest__e evt : Trigger.new) {
//        if (String.isNotBlank(evt.Payload__c)) {
//            try {
//                Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(evt.Payload__c);
//                String userId = (String) payloadMap.get('userId');
//                String policyCode = (String) payloadMap.get('policyCode');
//                String source = (String) payloadMap.get('source');
//
//                // 정책 코드가 없다면 수동/인바운드로 간주
//                if (String.isBlank(policyCode)) {
//                    policyCode = String.isNotBlank(source) && source.contains('TEAMS') ? 'INBOUND_COMMAND' : 'MANUAL_OVERRIDE';
//                }
//
//                if (String.isNotBlank(userId)) {
//                    String auditKey = userId + '_' + policyCode + '_' + todayStr;
//
//                    if (!auditLogsToUpsert.containsKey(auditKey)) {
//                        auditLogsToUpsert.put(auditKey, new SecurityAuditLog__c(
//                            AuditKey__c = auditKey,
//                            User__c = userId,
//                            PolicyCode__c = policyCode,
//                            Source__c = String.isNotBlank(source) ? source : 'SYSTEM_ACTION',
//                            MaxSeverity__c = 'CRITICAL' // 관리자 강제 타격이므로 심각도를 CRITICAL로 올림
//                        ));
//                    }
//                }
//            } catch (Exception e) {
//                System.debug('🚨 SecurityActionRequest Trigger Payload Parse Failed: ' + e.getMessage());
//            }
//        }
//    }
//
//    // 2. AuditLog Upsert 수행 (부모 레코드 강제 생성/업데이트)
//    if (!auditLogsToUpsert.isEmpty()) {
//        try {
//            // 외부 ID (AuditKey__c) 기준으로 Upsert 하여, 기존에 탐지기로 생성된 AuditLog가 있다면 병합됨!
//            Database.upsert(auditLogsToUpsert.values(), SecurityAuditLog__c.Fields.AuditKey__c, true);
//        } catch (Exception e) {
//            System.debug('🚨 SecurityActionRequest Trigger AuditLog Upsert Failed: ' + e.getMessage());
//        }
//    }
//
//    // 3. 보안 액션 트랜잭션 벌크 처리 (startAsyncContext ~ flushAsyncContext)
//    SecurityActionExecutor.startAsyncContext();
//
//    for (SecurityActionRequest__e evt : Trigger.new) {
//        try {
//            SecurityTypes.ActionDescriptor descr = SecurityActionFactory.getAction(evt.ActionName__c);
//            if (descr != null) {
//                SecurityActionExecutor.execute(descr.action, evt.Payload__c, descr.mode);
//            } else {
//                System.debug('🚨 SecurityActionRequest Trigger Failed: Unknown Action Type ' + evt.ActionName__c);
//            }
//        } catch (Exception e) {
//            System.debug('🚨 SecurityActionRequest Trigger Execute Failed: ' + e.getMessage());
//        }
//    }
//
//    SecurityActionExecutor.flushAsyncContext();
}