public with sharing class ContactUsController {
    public ContactUsController() {}
    
    // 카테고리 동적 할당
    // return : 카테고리 pickList
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCategoryList(){
        System.debug('getCategoryList...........................' + ContactUs__c.Category__c.getDescribe());
        try {
            // 동적으로 pickList 값 가져오기
            List<Map<String, String>> options = new List<Map<String, String>>();
            Schema.DescribeFieldResult fieldResult = ContactUs__c.Category__c.getDescribe();
            List<Schema.PicklistEntry> categoryList = fieldResult.getPicklistValues();
            System.debug(categoryList);
            // List에 Map 넣어주기. Map을 만들때 => 를 사용하면 바로 넣어줄 수 있음.
            for( Schema.PicklistEntry f : categoryList) {
                options.add(new Map<String, String>{
                                'label' => f.getLabel(),
                                'value' => f.getValue()
                });
            }
            return options;
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }    

    // contactUs 등록
    // return : recordId (redirect에 활용)Name
    @AuraEnabled
    public static String insertContactUs(Map<String, Object> contactUsInfo){
        System.debug('contactUsInfo.keySet@@@@@@@@@@@@@@@@@@@@' + contactUsInfo.keySet().toString());
        System.debug('contactUsInfo.values@@@@@@@@@@@@@@@@@@@@' + contactUsInfo.values());
        try {
            // lwc에서 가져온 정보로 contactUs 생성
            ContactUs__c contactUs = new ContactUs__c();
            contactUs.Collaborators__c = (String)contactUsInfo.get('CCList');
            contactUs.Category__c = (String)contactUsInfo.get('category');
            contactUs.Description__c = (String)contactUsInfo.get('description');
            contactUs.Requestor__c = (String)contactUsInfo.get('email');
            contactUs.Subject__c = (String)contactUsInfo.get('subject');
            contactUs.Account__c = [SELECT Id FROM account WHERE Name = 'Test Contact Us Account'].Id;
            contactUs.Status__c = 'Received';
            

            // fileList를 List<Map<String, String>>형태로 받기, 직렬화 & 반직렬화
            String files = JSON.serialize(contactUsInfo.get('fileList'));
            List<Map<String, String>> fileList = (List<Map<String, String>>)JSON.deserialize(files, List<Map<String, String>>.class);
            
            // 저장 후 record Id값을 받아서 업로드 된 파일과 연결
            insert contactUs;
            linkFileByContactUs(contactUs.Id, fileList);

            // record Id값으로 lwc에서 redirect에 활용
            return contactUs.Id;

        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // 입력된 파일을 contactUs와 연결
    private static void linkFileByContactUs(String contactUsId, List<Map<String, String>> fileList) {
        try {
            if(!fileList.isEmpty()) {
                // 파일, recordId로 링크 추가
                List<ContentDocumentLink> cdlList = new List<ContentDocumentLink>();
                for(Map<String, String> file : fileList) {
                    ContentDocumentLink cdl = new ContentDocumentLink();
                    cdl.ContentDocumentId = file.get('documentId');
                    cdl.LinkedEntityId = contactUsId;
                    cdl.ShareType = 'V';            // 'V'는 레코드와 관련된 모든 사용자에게 공유
                    cdl.Visibility = 'AllUsers';    // 레코드와 연결된 사용자의 가시성 설정
                    cdlList.add(cdl);
                }
                // db 접근은 반복문 밖에서
                insert cdlList;
            }
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

}