/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
global class EmailHandler implements Messaging.InboundEmailHandler {
    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {

        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        try {
            EmailMessage newEmail = new EmailMessage();

            newEmail.FromAddress = email.fromAddress;
            newEmail.ToAddress = envelope.toAddress;
            newEmail.Subject = email.subject;
            newEmail.TextBody = email.plainTextBody;
            newEmail.HtmlBody = email.htmlBody;
            newEmail.Incoming = true;
            newEmail.Status = '3'; // 수신됨 (Received)
            insert newEmail;

            if (email.binaryAttachments != null && email.binaryAttachments.size() > 0) {
                for (Messaging.InboundEmail.BinaryAttachment attachment : email.binaryAttachments) {
                    if (attachment.fileName.endsWith('.csv')) {
                        ContentVersion contentVersion = new ContentVersion();

                        contentVersion.Title = attachment.fileName;
                        contentVersion.PathOnClient = attachment.fileName;
                        contentVersion.VersionData = attachment.body;
                        contentVersion.FirstPublishLocationId = newEmail.Id;
                        insert contentVersion;

                        doUpdateProcess(attachment.body.toString());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error processing email: ' + e.getMessage());
        }
        return result;
    }

    @Future
    public static void doUpdateProcess(String csvString) {
        List<Map<String, Object>> records = parseCSVToList(csvString);
        // TODO 작업필요

    }

    public static List<Map<String, Object>> parseCSVToList(String csvContent) {
        List<Map<String, Object>> recordsList = new List<Map<String, Object>>();

        List<String> lines = csvContent.split('\n');
        if (lines.size() < 2) return recordsList;

        // 헤더(컬럼명) 추출
        List<String> headers = lines[0].trim().split(',');
        System.debug(headers);
        // 데이터 처리
        for (Integer lineIdx = 1; lineIdx < lines.size(); lineIdx++) {
            String line = lines[lineIdx].trim();
            if (String.isEmpty(line)) continue;

            // 컬럼명(Key) - 값(Value) 매핑
            List<String> values = line.split(',');
            System.debug(values);
            Map<String, Object> recordMap = new Map<String, Object>();
            for (Integer columnIdx = 0; columnIdx < headers.size(); columnIdx++) {
                String key = headers[columnIdx].trim();
                String rawValue = values[columnIdx].trim();
                Object value = parseValue(rawValue);

                recordMap.put(key, value);
            }
            recordsList.add(recordMap);
        }
        return recordsList;
    }

    public static Object parseValue(String rawValue) {
        List<String> booleanPattern = new List<String>{'TRUE', 'FALSE'};
        Pattern decimalPattern = Pattern.compile('^-?\\d*(\\.\\d+)?$');

        if (String.isEmpty(rawValue) || rawValue.equalsIgnoreCase('null')) return null;
        if (booleanPattern.contains(rawValue.toUpperCase())) return Boolean.valueOf(rawValue);
        if (decimalPattern.matcher(rawValue).matches()) return Decimal.valueOf(rawValue);

        return rawValue;
    }

}