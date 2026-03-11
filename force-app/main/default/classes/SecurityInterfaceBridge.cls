/**
* @Author            : jh.jung
* @Description       : Security 액션에서 사내 자체 프레임워크인 Interface(RealTime/Queueable/Batch)를 호출하기 위한 브리지.
* @Deprecated        : Tier 2 Flyweight 패턴 도입(`SecurityBaseWebhookAction`)으로 인해 SOAR의 핵심 웹훅 기능에서는 더 이상 이 브리지를 타지 않습니다.
*                      고객사가 자체 레거시 통신망(`Interface__c`)과 SOAR를 연동하고 싶을 때 확장용으로 쓰기 위한 하위 호환성(Legacy) 목적으로만 남겨둡니다.
*/
public with sharing class SecurityInterfaceBridge {

    public enum Mode {
        REALTIME,
        QUEUEABLE,
        BATCH
    }

    public class IntegrationNotFoundException extends Exception {}

    public class IntegrationSetting {
        public String actionType;
        public String interfaceId;
        public Mode mode;
        public Boolean isActive;
    }

    // ActionType 기준으로 SecurityIntegration__mdt 조회
    private static IntegrationSetting resolve(String actionType) {
        if (String.isBlank(actionType)) {
            throw new IntegrationNotFoundException('ActionType is blank.');
        }

        List<SecurityIntegration__mdt> rows = [
            SELECT ActionType__c, InterfaceId__c, Mode__c, IsActive__c
            FROM SecurityIntegration__mdt
            WHERE ActionType__c = :actionType
            AND IsActive__c = true
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new IntegrationNotFoundException('No active SecurityIntegration__mdt for ActionType: ' + actionType);
        }

        SecurityIntegration__mdt r = rows[0];
        IntegrationSetting s = new IntegrationSetting();
        s.actionType = r.ActionType__c;
        s.interfaceId = r.InterfaceId__c;
        s.mode = String.isBlank(r.Mode__c) ? Mode.REALTIME : Mode.valueOf(r.Mode__c);
        s.isActive = r.IsActive__c;
        return s;
    }

    /**
     * @description ActionType 기반으로 적절한 Interface를 찾아 payload를 전송한다.
     *              - REALTIME: InterfaceRealTime 기반 구현체
     *              - QUEUEABLE: InterfaceQueueable 기반 구현체
     *              - BATCH: InterfaceBatch 기반 구현체
     */
    public static Object callForAction(String actionType, String payloadJson) {
        IntegrationSetting s = resolve(actionType);

        IInterfaceExecutor exec = InterfaceFactory.createInstance(s.interfaceId);

        // RealTime/Queueable/Batch 모두 IInterfaceExecutor.call(Object)를 구현
        // payloadJson은 구현체에서 this.request로 받아 적절히 가공한다.
        return exec.call(payloadJson);
    }
}