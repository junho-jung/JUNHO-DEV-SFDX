/**
* @Author            : jh.jung
* @Description 		 : 보안 메타데이터(SecurityPolicy__mdt, SecurityInboundAction__mdt 등)를
* 트랜잭션 수명 주기 동안 단 한 번만 로드하여 메모리에 캐싱하는 싱글톤 레지스트리.
* SOQL 쿼리 리밋(100 limits)을 보호하고, 고객사의 커스텀 오버라이드(Override) 설정을
* 코어 패키지와 매끄럽게 연결하기 위한 Tier 2 핵심 아키텍처입니다.
* @Target            : 
* @Modification Log
* Ver      Date            Author           Modification
* ===================================================================================
* 1.0      2026-03-11      jh.jung           Created - Singleton Metadata Registry (Tier 2)
*/
public with sharing class SecurityMetadataRegistry {

    // =================================================================
    // 1. Singleton Instance
    // =================================================================
    private static SecurityMetadataRegistry instance;

    // =================================================================
    // 2. Cache Maps
    // =================================================================
    // PolicyCode__c => SecurityPolicy__mdt
    private Map<String, SecurityPolicy__mdt> cachedPolicies;
    
    // ActionType__c => SecurityInboundAction__mdt
    private Map<String, SecurityInboundAction__mdt> cachedInboundActions;

    // =================================================================
    // 3. Constructor & Initialization
    // =================================================================
    
    /**
     * @description 외부 인스턴스화 방지 (싱글톤 패턴)
     */
    private SecurityMetadataRegistry() {
        this.cachedPolicies = new Map<String, SecurityPolicy__mdt>();
        this.cachedInboundActions = new Map<String, SecurityInboundAction__mdt>();
        
        loadAllMetadata();
    }

    /**
     * @description 유일무이한 인스턴스를 반환
     */
    public static SecurityMetadataRegistry getInstance() {
        if (instance == null) {
            instance = new SecurityMetadataRegistry();
        }
        return instance;
    }

    /**
     * @description 생성 시점에서 필요한 모든 메타데이터를 일괄 캐싱함
     */
    private void loadAllMetadata() {
        // 1. Load All Active Policies
        for (SecurityPolicy__mdt p : [
            SELECT Id, PolicyCode__c, IsActive__c, ActionTypes__c, ActionButtons__c,
                   ThresholdLow__c, ActionLow__c, ThresholdMedium__c, ActionMedium__c, 
                   ThresholdHigh__c, ActionHigh__c, ThresholdCritical__c, ActionCritical__c
            FROM SecurityPolicy__mdt
            WHERE IsActive__c = true
        ]) {
            this.cachedPolicies.put(p.PolicyCode__c, p);
        }

        // 2. Load All Active Inbound Actions
        for (SecurityInboundAction__mdt a : [
            SELECT Id, InboundActionType__c, ActionClassName__c, IsActive__c, ExecutionMode__c
            FROM SecurityInboundAction__mdt
            WHERE IsActive__c = true
        ]) {
            this.cachedInboundActions.put(a.InboundActionType__c, a);
        }
    }

    // =================================================================
    // 4. Public Accessors
    // =================================================================

    /**
     * @description PolicyCode에 해당하는 정책을 반환 (캐시 사용)
     * @param policyCode 정책 식별자
     */
    public SecurityPolicy__mdt getPolicy(String policyCode) {
        if (String.isBlank(policyCode)) return null;
        return this.cachedPolicies.get(policyCode);
    }

    /**
     * @description ActionType에 배열된 액션 메타데이터 반환 (캐시 사용)
     */
    public SecurityInboundAction__mdt getInboundAction(String actionType) {
        if (String.isBlank(actionType)) return null;
        return this.cachedInboundActions.get(actionType.trim().toUpperCase());
    }
}