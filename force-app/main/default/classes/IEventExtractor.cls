public interface IEventExtractor {
    SecurityAlertPublisher.ResourceInfo extract(SObject rawEvent, Map<String, Object> payload);
}
