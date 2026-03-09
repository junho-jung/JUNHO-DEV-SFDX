public with sharing class S3ObjectController {
    public S3ObjectController() {}

    // 조회중인 Contact의 accountId을 갖고있는 모든 Contact를 List로 조회
    @AuraEnabled
    public static List<S3Files__c> getS3FileList(String recordId) {
        System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@ getS3ObjectList start');
        try {
            
            List<S3Files__c> S3FilesList = [
                SELECT Name, Extention__c, CreatedDate 
                FROM S3Files__c 
                WHERE RelationRecord__c = :recordId
            ];
            return S3FilesList;
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // todo: 파일 등록 : S3에 등록 후 S3Files__c 등록
    @AuraEnabled
    public static String saveFileByS3(Id recordId, String fileName, String base64Data, String contentType){
        System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@ saveFileByS3 start');
        // savepoint 쓰려면 http callout에 대한 처리가 필요함. 일단 보류
        // http callout이랑 savepoint는 같이 사용 불가.
        // SavePoint sp = Database.setSavepoint();
        String returnValue;
        try {
            // 이름, 확장자 분리
            Integer lastpoint = fileName.lastIndexOf('.');
            // 이름 중복 확인하고 거부
            // 이름 겹치는지 확인 : 서버에서 하지말고 lwc에서 하자.
            List<S3Files__c> fileCheck = [SELECT Id, Name FROM S3Files__c WHERE Name = :fileName.substring(0, lastpoint) AND Extention__c = :fileName.substring(lastpoint+1) AND RelationRecord__c = :recordId];
            System.debug('fileCheck.isEmpty()..............' + fileCheck.isEmpty());

            if(!fileCheck.isEmpty()) {
                System.debug('동일한 파일 존재');
                return 'fail';
            }

            // S3에 저장
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:S3_FileUpload/'+recordId+'/'+fileName.replace(' ', 'NBSP'));
            req.setMethod('PUT');
            req.setBodyAsBlob(EncodingUtil.base64Decode(base64Data));

            HTTP http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('res.getStatusCode().......................' + res.getStatusCode());
            System.debug('res.getStatus().......................' + res.getStatus());

            // 셀포에 등록
            // if 200 || 201 만 insert
            if(res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                S3Files__c file = new S3Files__c();
                // Integer lastpoint = fileName.lastIndexOf('.');
                file.Name = fileName.substring(0, lastpoint);
                file.Extention__c = fileName.substring(lastpoint+1);
                file.RelationRecord__c = recordId;
                
                insert file;
            }

            returnValue = 'success';
            
        } catch (Exception e) {
            
            // Database.rollback(sp);
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            // throw new AuraHandledException(e.getMessage());
            returnValue = 'fail';
        }
        return returnValue;
    }

    // todo: S3에서 다운받기
    @AuraEnabled
    public static String downloadFileByS3(Id recordId, String fileName){ 
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:S3_FileUpload/'+recordId+'/'+fileName.replace(' ', 'NBSP'));
            req.setMethod('GET');
            HTTP http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('res.getStatusCode().......................' + res.getStatusCode());
            System.debug('res.getStatus().......................' + res.getStatus());
            

            System.debug('res...........' + res);
            // String base64EncodedFile = EncodingUtil.base64Encode(Blob.valueOf(res.getBody()));
            String base64EncodedFile = EncodingUtil.base64Encode(res.getBodyAsBlob());
            return base64EncodedFile;

        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // todo: 파일 삭제 : S3에 삭제 후 S3Files__c 에서도 삭제
    @AuraEnabled
    public static void deleteFileByS3(Id recordId, String Name, String Extention){
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:S3_FileUpload/'+recordId+'/'+Name.replace(' ', 'NBSP')+'.'+Extention);
            req.setMethod('DELETE');
            HTTP http = new Http();
            HTTPResponse res = http.send(req);
            System.debug('res.getStatusCode().......................' + res.getStatusCode());
            System.debug('res.getStatus().......................' + res.getStatus());
            
            S3Files__c file = [SELECT Id FROM S3Files__c WHERE Name = :Name AND Extention__c = :Extention AND RelationRecord__c = :recordId];
            delete file;

        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }



    // S3에서 ObjectList 받아오기
    // @AuraEnabled
    // public static List<Map<String, String>> getS3ObjectList(){
    //     try {
    //         HttpRequest req = new HttpRequest();
    //         req.setEndpoint('callout:S3_FileUpload');
    //         req.setMethod('GET');
    //         req.setHeader('Content-Type','application/xml');
    //         HTTP http = new Http();
    //         HTTPResponse res = http.send(req);


            
    //         System.debug('res.getStatusCode().......................' + res.getStatusCode());   // 200
    //         System.debug('res.getStatus().......................' + res.getStatus());           // OK
    //         System.debug('res.getBody().......................' + res.getBody());
            
    //         if(res.getStatusCode() == 200) {
    //             Dom.Document xmlDoc = new Dom.Document();
    //             xmlDoc.load(res.getBody());

    //             List<Map<String, String>> contents = new List<Map<String, String>>();
    //             // xmlDoc.getRootElement().getChildElement('contents');

    //             for (Dom.XmlNode node : xmlDoc.getRootElement().getChildren()) {
    //                 if(node.getName() == 'Contents') {
    //                     // 파일 발견
    //                     Map<String, String> fileInfoMap = new Map<String, String>();
    //                     for(Dom.XmlNode fileInfo : node.getChildElements()) {
    //                         if(fileInfo.getName() == 'Key') {
    //                             String name = fileInfo.getText();
    //                             Integer lastIndex = name.lastIndexOf('.');
    //                             fileInfoMap.put('fileName', name.substring(0, lastIndex));
    //                             fileInfoMap.put('fileExtention', name.substring(lastIndex+1));
    //                         }
    //                         else if(fileInfo.getName() == 'LastModified')
    //                             fileInfoMap.put('createdDate', fileInfo.getText());
    //                         // 추가 정보 필요 없으면 삭제
    //                         else {
    //                             fileInfoMap.put(fileInfo.getName(), fileInfo.getText());
    //                         }
    //                     }
    //                     contents.add(fileInfoMap);
    //                 }   
    //             }

    //             return contents;
    //         } else {
    //             return null;
    //         }
    //     } catch (Exception e) {
    //         System.debug('getLineNumber: '+e.getLineNumber());
    //         System.debug('error: '+e.toString());
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }
}