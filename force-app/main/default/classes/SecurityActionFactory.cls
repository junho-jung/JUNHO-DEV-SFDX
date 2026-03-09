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

        switch on formattedType {

            // [SYNC] 즉각적인 대응이 필요한 사용자 제어 액션
            when 'KILL_SESSION' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityKillSessionAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            when 'FREEZE_USER' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityFreezeUserAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            when 'REVOKE_OAUTH_TOKENS' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityRevokeOauthTokensAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            when 'QUARANTINE_PROFILE' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityQuarantineProfileAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            when 'REQUIRE_MFA_PASSWORD_RESET' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityResetPasswordAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            when 'RESTRICT_PERMISSION' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityRestrictPermissionAction(),
                    SecurityTypes.ActionExecutionMode.SYNC
                );
            }

            // [ASYNC] 외부 연동이나 데이터 생성 등 지연 실행이 가능한 액션
            when 'NOTIFY_SLACK' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityNotifySlackAction(),
                    SecurityTypes.ActionExecutionMode.ASYNC
                );
            }

            when 'NOTIFY_TEAMS' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityNotifyTeamsAction(),
                    SecurityTypes.ActionExecutionMode.ASYNC
                );
            }

            when 'NOTIFY_MANAGER_EMAIL' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityNotifyManagerEmailAction(),
                    SecurityTypes.ActionExecutionMode.ASYNC
                );
            }

            when 'CREATE_CASE' {
                return new SecurityTypes.ActionDescriptor(
                    new SecurityCreateCaseAction(),
                    SecurityTypes.ActionExecutionMode.ASYNC
                );
            }

            when 'SEND_TO_SIEM' {
                return new SecurityTypes.ActionDescriptor(
                    new SecuritySendToSiemAction(),
                    SecurityTypes.ActionExecutionMode.ASYNC
                );
            }

            when else {
                SecuritySoarTrace.log('SecurityActionFactory.getAction.unknown_action', new Map<String, Object>{
                    'actionType' => actionType
                });
                return null;
            }
        }
    }
}