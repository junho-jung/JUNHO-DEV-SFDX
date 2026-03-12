global interface ISecurityFilter {
    Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc);
}