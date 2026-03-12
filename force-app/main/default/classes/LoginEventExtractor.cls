public class LoginEventExtractor implements IEventExtractor {
    public SecurityAlertPublisher.ResourceInfo extract(SObject rawEvent, Map<String, Object> payload) {
        SecurityAlertPublisher.ResourceInfo info = new SecurityAlertPublisher.ResourceInfo();
        LoginEvent le = (LoginEvent) rawEvent;
        info.setValues(le.LoginHistoryId, le.LoginType, 'LoginEvent');
        payload.put('sourceIp', le.SourceIp);
        payload.put('status', le.Status);
        return info;
    }
}