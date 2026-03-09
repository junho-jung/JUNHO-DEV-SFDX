/**
 * @Description 권한 상승 패턴(Privilege Escalation Pattern) 구현체.
 *              인바운드 웹훅(Site Guest User)이나 권한이 부족한 내부 관리자가 시스템 중요 보안 조치(User 동결 등)를
 *              수행해야 할 때, 한시적이고 안전하게 "Automated Process(System)" 권한으로 액션을 실행합니다.
 *              이를 위해 Platform Event 기반 재호출 아키텍처를 사용합니다.
 */
public without sharing class SecurityPrivilegeEscalator {

    /**
     * @description 외부 요청이나 LWC 액션의 한계를 돌파하기 위해 플랫폼 이벤트(SecurityActionRequest__e)를 발행
     * @param actionType 실행할 액션 타입 식별자 (예: 'KILL_SESSION')
     * @param payload 액션에 전달할 JSON 문자열
     */
    public static void executeAsSystem(String actionType, String payload) {
        SecuritySoarTrace.log('SecurityPrivilegeEscalator.executeAsSystem', new Map<String, Object>{
            'actionType' => actionType,
            'mechanism' => 'PlatformEvent_Publish'
        });
        
        // --- 1급 객체인 Platform Event를 통한 완벽한 문맥 분리 (Context Break) ---
        // 이벤트가 발행되면 트리거가 'Automated Process' 사용자로 돌게 되어 Guest 제약조건을 우회할 수 있음.
        SecurityActionRequest__e evt = new SecurityActionRequest__e(
            ActionName__c = actionType,
            Payload__c = payload
        );
        EventBus.publish(evt);
    }
}