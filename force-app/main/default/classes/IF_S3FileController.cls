@RestResource(urlMapping='/api/fileupload')
global without sharing class IF_S3FileController {

    // todo: 파일 등록 : S3에 등록 후 S3Files__c 등록
    @HttpPost
    global static void saveFileByS3(){
        System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@ saveFileByS3 start');

        // System.debug('formData: ' + formData);
        // System.debug('formData.size(): ' + formData.size());

        
        try {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;

            Blob fileBlob = req.requestBody;

            System.debug(fileBlob);
            // for(String key : formData.keySet()) {
            //     System.debug('formData.get(key): ' + formData.get(key));
            // }

            // HttpRequest req = new HttpRequest();
            // req.setEndpoint('callout:S3_FileUpload');
            // req.setMethod('POST');
            // req.setHeader('Content-Type','application/xml');
            // HTTP http = new Http();
            // HTTPResponse res = http.send(req);
            
            // return true;

            // return 'File uploaded successfully';
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getLineNumber());
            throw new AuraHandledException(e.getMessage());
        }
    }

    // todo: 파일 삭제 : S3에 삭제 후 S3Files__c 등록
    // public static boolean deleteFileByS3(){  
    //     try {
            
    //     } catch (Exception e) {
    //         System.debug(e.getMessage());
    //         System.debug(e.getLineNumber());
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }
}