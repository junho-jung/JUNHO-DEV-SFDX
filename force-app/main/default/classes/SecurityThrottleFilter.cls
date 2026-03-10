public class SecurityThrottleFilter implements ISecurityFilter {
    public Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc) {
        if (actionDesc == null || actionDesc.action == null) return false;
        String logActionName = String.valueOf(actionDesc.action).substringBefore(':');
        
        if (SecurityActionThrottle.isThrottled(alert.UserId, alert.PolicyCode, logActionName)) {
            System.debug(LoggingLevel.WARN, 'SecurityThrottleFilter ::: Throttled: ' + actionType);
            return false;
        }
        return true;
    }
}
