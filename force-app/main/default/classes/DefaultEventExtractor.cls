public class DefaultEventExtractor implements IEventExtractor {
    public SecurityAlertPublisher.ResourceInfo extract(SObject rawEvent, Map<String, Object> payload) {
        SecurityAlertPublisher.ResourceInfo info = new SecurityAlertPublisher.ResourceInfo();
        String objName = rawEvent.getSObjectType().getDescribe().getName();
        info.setValues((String)rawEvent.get('EventIdentifier'), 'Event: ' + objName, objName);
        return info;
    }
}
