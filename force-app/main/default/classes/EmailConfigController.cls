/**
* @Author            : jh.jung
* @Description 		 : Email Util Controller
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
public without sharing class EmailConfigController {

    private static final String ALGORITHM_KEY = 'AES256';
    private static final String HASH_KEY = 'SHA-256';

    /**
     * @date            2024-10-15
     * @author          payo03@solomontech.net
     * @param           mailInfoList E-Mail 전송 Key-Value값 Setting
     * @description     Key - Value 정리사항
     *  1. 수신자
     *     Key : 'to' / Value Type : List<String>
     *  2. 제목
     *     Key : 'subject' / Value Type : String
     *  3. 내용
     *     Key : 'body' / Value Type : String
     *  4. 암호화 여부(선택사항)
     *     key : 'encrypt', 'encryptSHA' / Value Type : Boolean
     *  5. 송신 사용자(선택사항)
     *     key : 'sender' / Value Type : String
     *  6. 참조(선택사항)
     *     Key : 'cc' / Value Type : List<String>
     *  7. 숨은참조(선택사항)
     *     Key : 'bcc' / Value Type : List<String>
     *  8. 파일(선택사항)
     *     Key : 'fileList' / value Type : List<Messaging.EmailFileAttachment>
     * @return          List<Messaging.SendEmailResult>
     */
    public static Boolean sendEmail(List<Map<String, Object>> mailInfoList) {
        String strDate = CommonUtilController.formatDate(Datetime.now(), 'C');
        List<Messaging.SingleEmailMessage> emailList = new List<Messaging.SingleEmailMessage>();

        Map<String, Map<String, String>> encryptMap = new Map<String, Map<String, String>>();
        for(Map<String, Object> mailInfo : mailInfoList) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

            List<String> toAddress = (List<String>) mailInfo.get('to');
            String subject = String.valueOf(mailInfo.get('subject'));
            String body = String.valueOf(mailInfo.get('body'));
            Boolean isEncrypt = mailInfo.get('encrypt') != null ? (Boolean) mailInfo.get('encrypt') : false;
            Boolean isEncryptSHA = mailInfo.get('encryptSHA') != null ? (Boolean) mailInfo.get('encryptSHA') : false;
            String sender = mailInfo.get('sender') != null ? (String) mailInfo.get('sender') : null;
            List<String> ccAddress = mailInfo.get('cc') != null ? (List<String>) mailInfo.get('cc') : new List<String>();
            List<String> bccAddress = mailInfo.get('bcc') != null ? (List<String>) mailInfo.get('bcc') : new List<String>();
            List<Messaging.EmailFileAttachment> fileList = mailInfo.get('fileList') != null ? (List<Messaging.EmailFileAttachment>) mailInfo.get('fileList') : new List<Messaging.EmailFileAttachment>();

            String key = strDate + '_' + UserInfo.getUserEmail() + '_' + subject + '%';
            if(isEncrypt || isEncryptSHA) {
                Map<String, String> returnMap = new Map<String, String>();
                if(isEncrypt) returnMap = encryptEmailBody(body);
                if(isEncryptSHA) returnMap = encryptEmailBodySHA(body);

                body = returnMap.get('encryptBody');
                encryptMap.put(key, returnMap);
            }

            String replaceBody = body.replace('<br>', '\n');

            email.setToAddresses(toAddress);
            email.setSubject(subject);
            email.setPlainTextBody(replaceBody);
            if (sender != null) email.setSenderDisplayName(sender);
            if (!ccAddress.isEmpty()) email.setCcAddresses(ccAddress);
            if (!bccAddress.isEmpty()) email.setBccAddresses(bccAddress);
            if (!fileList.isEmpty()) email.setFileAttachments(fileList);

            emailList.add(email);
            System.debug(email);
        }

        // ver1.1 Email 동시 전송시점에 의해 ExteranlId 중복에러 방지
        for(Integer i = 0; i < 3; i++) {
            // 최대 3번까지 호출
            Boolean dupRow = false;

            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emailList);
                System.debug(results);

                Map<String, EmailMessage> updateMap = new Map<String, EmailMessage>();
                for (EmailMessage message : [
                    SELECT Id, ExternalId__c, EncryptKey__c, TextBodyRaw__c
                    FROM EmailMessage
                    WHERE ExternalId__c LIKE :encryptMap.keySet()
                    ORDER BY CreatedDate DESC, ExternalId__c DESC
                ]) {
                    String externalId = message.ExternalId__c;
                    Integer lastIndex = externalId.lastIndexOf('_');
                    String messageKey = externalId.substring(0, lastIndex) + '%';

                    Map<String, String> encrypt = encryptMap.get(messageKey);
                    if (encrypt != null) {
                        message.EncryptKey__c = encrypt.get('encryptKey');
                        message.TextBodyRaw__c = encrypt.get('textBodyRaw');

                        // 보낸 메일만 암호화 작업
                        if (updateMap.get(messageKey) == null) updateMap.put(messageKey, message);
                    }
                }

                update updateMap.values();
            } catch (EmailException e) {
                System.debug(e.getMessage());
                for (Integer idx = 0; idx < e.getNumDml(); idx++) {
                    System.debug('getDmlType : [' + e.getDmlType(idx).name() + ']');
                    System.debug('getDmlMessage : ' + e.getDmlMessage(idx) + ']');

                    if (e.getDmlType(idx) == StatusCode.DUPLICATE_VALUE) dupRow = true;
                }
            } catch (Exception e) {
                // Email외에 내용들은 진행되야함
                System.debug(e.getMessage());
            } finally {
                if (!dupRow) break;
            }
        }

        return true;
    }

    /**
     * @param           emailBody E-Mail Body 전송내용
     * @return          Map<String, String>
     * @description     Return Key - Value 정리사항
     *  1. Encrypt Key
     *     Key : 'encryptKey' / Value Type : String
     *  2. E-Mail Body
     *     Key : 'encryptBody' / Value Type : String
     *  3. E-Mail Body Raw
     *     Key : 'textBodyRaw' / Value Type : String
     */
    public static Map<String, String> encryptEmailBody(String emailBody) {
        Map<String, String> returnMap = new Map<String, String>();
        Blob encryptKey = Crypto.generateAesKey(256);
        Blob encryptedBody = Crypto.encryptWithManagedIV(
            ALGORITHM_KEY,
            encryptKey,
            Blob.valueOf(emailBody)
        );

        returnMap.put('encryptKey', EncodingUtil.base64Encode(encryptKey));
        returnMap.put('encryptBody', EncodingUtil.base64Encode(encryptedBody));
        returnMap.put('textBodyRaw', emailBody);

        return returnMap;
    }

    // 이메일 내용 복호화(AES256)
    public static String decryptEmailBody(Blob decryptKey, Blob decryptBody) {
        return Crypto.decryptWithManagedIV(
            ALGORITHM_KEY,
            decryptKey,
            decryptBody
        ).toString();
    }

    public static String decryptEmailBody(String key, String body) {
        Blob decryptKey = EncodingUtil.base64Decode(key);
        Blob decryptBody = EncodingUtil.base64Decode(body);

        return decryptEmailBody(decryptKey, decryptBody);
    }

    // SHA 방식의 Hash
    public static String encryptString(String key, String body) {
        Blob blobBody = Blob.valueOf(key + body);
        Blob hashedBlob = Crypto.generateDigest(HASH_KEY, blobBody);

        return EncodingUtil.convertToHex(hashedBlob);
    }

    public static Map<String, String> encryptEmailBodySHA(String emailBody) {
        Map<String, String> returnMap = new Map<String, String>();
        Decimal randomNumber = Math.random();
        Decimal round2Value = Math.round(randomNumber * 100000) / 100.0;

        String encryptKey = String.valueOf(round2Value);
        String encryptBody = encryptString(encryptKey, emailBody);

        // 암호화된 Text를 보관. 내용을 Email에 전송하고자 한다면 encryptBody와 textBodyRaw의 값을 서로 교체해줘야함
        returnMap.put('encryptKey', encryptKey);
        returnMap.put('encryptBody', encryptBody);
        returnMap.put('textBodyRaw', emailBody);

        return returnMap;
    }

    // 이메일 내용 확인(SHA-256)
    public static Boolean compareHash(String key, String body, String hashBody) {
        return encryptString(key, body) == hashBody;
    }

    /**
     * @param objectName        CSV 파일의 Object Name
     * @param collection        CSV 파일의 데이터 Id List or Id Set
     * @param fileName          CSV 파일명,            ex... Account 정보.csv
     * @param header            CSV 파일의 Header,     ex... 필드명1, 필드명2, 필드명.... 필드명10\n
     * @param csvBody           CSV 파일의 Body,       ex... 데이터1-1, 데이터1-2, 데이터1-3... 데이터 1-10\n 데이터2-1....
     * @return                  Email 첨부가능한 Messaging.EmailFileAttachment Return
     */
    public static Messaging.EmailFileAttachment returnCSV(String objectName, Object collection, String fileName, String header, String csvBody) {
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        List<String> fields = csvBody.split(',');

        String query = 'SELECT ' + csvBody + ' FROM ' + objectName + ' WHERE Id IN ' + CommonUtilController.joinedString(collection);
        List<SObject> records = Database.query(query);

        if(!fileName.contains('.csv')) fileName += '.csv';
        if(!header.contains('\n')) header += '\n';

        List<String> rows = new List<String>();
        for(SObject record : records) {
            String row = '';
            for(String field : fields) {
                field = field.trim();
                String value = String.valueOf(CommonUtilCustomController.fetchValueRecur(record, field));

                row += value + ',';
            }
            row = row.substring(0, row.length() - 1) + '\n';
            rows.add(row);
        }

        String csvData = header.replace(' ', '') + String.join(rows, '');
        // NO BOM ver ( AS-IS )
        // Blob csvBlob = Blob.valueOf(csvData);
        // attachment.setBody(csvBlob);

        // BOM ver // Commented - 1.11
        String csvDataWithBom = '\uFEFF' + csvData;
        Blob finalBlob = Blob.valueOf(csvDataWithBom);
        attachment.setBody(finalBlob);

        attachment.setFileName(fileName);
        // attachment.setContentType('text/csv');// Commented - 1.11
        attachment.setContentType('text/csv; charset=UTF-8');

        return attachment;
    }
}