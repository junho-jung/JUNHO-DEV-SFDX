public class SecurityFilterChain {
    private static List<ISecurityFilter> filters = new List<ISecurityFilter>{
        new SecurityThrottleFilter()
    };

    public static Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc) {
        for (ISecurityFilter filter : filters) {
            if (!filter.isAllowed(alert, actionType, actionDesc)) {
                return false;
            }
        }
        return true;
    }
}