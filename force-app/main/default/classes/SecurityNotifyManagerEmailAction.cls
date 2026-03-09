/**
 * @Description 알람 대상 유저의 직속 상사(User.Manager)에게 보안 위반 사실을
 *              이메일로 은밀하게 통보(Escalation)하는 액션.
 */
public with sharing class SecurityNotifyManagerEmailAction extends SecurityBaseAction {
    
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        String policyCode = (String) payloadMap.get('PolicyCode');
        String severity = (String) payloadMap.get('Severity');

        if (String.isBlank(targetUserId)) {
            SecuritySoarTrace.log('SecurityNotifyManagerEmailAction.execute.NoUserId');
            return;
        }

        SecuritySoarTrace.log('SecurityNotifyManagerEmailAction.execute', new Map<String, Object>{ 'UserId' => targetUserId });

        // 대상 유저의 직속 상사(Manager) 조회
        List<User> targetUsers = [
            SELECT Id, Name, ManagerId, Manager.Email, Manager.Name 
            FROM User 
            WHERE Id = :targetUserId AND ManagerId != null 
            LIMIT 1
        ];
        
        if (!targetUsers.isEmpty() && !String.isBlank(targetUsers[0].Manager.Email)) {
            User tUser = targetUsers[0];
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { tUser.Manager.Email });
            mail.setSubject('[SOAR Alert] Urgent Security Action Required: ' + tUser.Name);
            
            String body = 'Hello ' + tUser.Manager.Name + ',\n\n';
            body += 'A critical security violation was detected for your team member, ' + tUser.Name + '.\n';
            body += '- Policy Code: ' + (String.isNotBlank(policyCode) ? policyCode : 'N/A') + '\n';
            body += '- Severity: ' + (String.isNotBlank(severity) ? severity : 'N/A') + '\n\n';
            body += 'Please review the activity and take appropriate actions.\n\n';
            body += 'Salesforce SOAR Internal System';
            mail.setPlainTextBody(body);
            
            // 이메일 전송: Limit의 제약을 받을 수 있으므로 Queueable(ASYNC) 컨텍스트에서 실행되는 것을 권장
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            System.debug('🚨 SUCCESS: Sent notification email to Manager ' + tUser.Manager.Email);
        } else {
            SecuritySoarTrace.log('SecurityNotifyManagerEmailAction.execute.NoManagerFound');
        }
    }
}