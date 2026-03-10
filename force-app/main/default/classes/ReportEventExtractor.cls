public class ReportEventExtractor implements IEventExtractor {
    public SecurityAlertPublisher.ResourceInfo extract(SObject rawEvent, Map<String, Object> payload) {
        SecurityAlertPublisher.ResourceInfo info = new SecurityAlertPublisher.ResourceInfo();
        ReportEvent re = (ReportEvent) rawEvent;
        info.setValues(re.ReportId, getReportName(re.ReportId), 'ReportEvent');
        payload.put('actionName', re.ActionName);
        payload.put('format', re.Format);
        return info;
    }

    private static String getReportName(Id reportId) {
        if (reportId == null) return 'N/A';
        for (Report r : [SELECT Name FROM Report WHERE Id = :reportId LIMIT 1]) return r.Name;
        return 'Unknown Report (' + reportId + ')';
    }
}
