/**
* @Author            : jh.jung
* @Description 		 : ActionType 문자열에 따라 구체적인 Action 클래스와 실행 모드(SYNC/ASYNC)를 반환함.
* 신규 보안 액션이 추가될 경우 이 클래스의 switch 구문에 케이스를 추가해야 함.
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
public class SecurityActionFactory {

    /**
     * @description 요청된 타입에 맞는 ActionDescriptor 객체를 생성하여 반환
     * @param actionType 'KILL_SESSION', 'NOTIFY_SLACK' 등 구분값
     * @return SecurityTypes.ActionDescriptor (Action 인스턴스 + 실행 모드)
     */
    public static SecurityTypes.ActionDescriptor getAction(String actionType) {
        if (String.isBlank(actionType)) return null;

        // 대소문자 구분 없이 처리하기 위해 Uppercase 변환
        String formattedType = actionType.trim().toUpperCase();

        try {
            SecurityInboundAction__mdt mapping = SecurityMetadataRegistry.getInstance().getInboundAction(formattedType);

            if (mapping == null) {
                SecuritySoarTrace.log('SecurityActionFactory.getAction.unknown_action', new Map<String, Object>{
                    'actionType' => formattedType
                });
                return null;
            }

            // 리플렉션(Reflection)을 통한 동적 인스턴스 생성
            Type t = Type.forName(mapping.ActionClassName__c);
            if (t == null) {
                SecuritySoarTrace.log('SecurityActionFactory.getAction.invalid_class', new Map<String, Object>{
                    'className' => mapping.ActionClassName__c
                });
                return null;
            }

            ISecurityAction actionInstance = (ISecurityAction) t.newInstance();
            
            SecurityTypes.ActionExecutionMode mode = mapping.ExecutionMode__c == 'ASYNC' 
                ? SecurityTypes.ActionExecutionMode.ASYNC 
                : SecurityTypes.ActionExecutionMode.SYNC;

            return new SecurityTypes.ActionDescriptor(actionInstance, mode);

        } catch (Exception e) {
            SecuritySoarTrace.log('SecurityActionFactory.getAction.error', new Map<String, Object>{
                'error' => e.getMessage(),
                'actionType' => formattedType
            });
            return null;
        }
    }
}