public class ApiEventExtractor implements IEventExtractor {
    public SecurityAlertPublisher.ResourceInfo extract(SObject rawEvent, Map<String, Object> payload) {
        SecurityAlertPublisher.ResourceInfo info = new SecurityAlertPublisher.ResourceInfo();
        ApiEvent ae = (ApiEvent) rawEvent;
        info.setValues(ae.LoginHistoryId, ae.Query, 'ApiEvent');
        payload.put('query', ae.Query);
        payload.put('rows', ae.RowsProcessed);
        return info;
    }
}