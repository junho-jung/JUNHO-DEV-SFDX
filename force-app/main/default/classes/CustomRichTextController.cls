/**
 * Created by blacktick on 26. 2. 26..
 */

public with sharing class CustomRichTextController {

    public String richTextHtml { get; set; }
    public String saveResult { get; set; } // [DEPRECATED] VF actionFunction oncomplete에서만 사용. 현재 주석 처리됨. constructor 내 할당은 무해하므로 유지.

    private Id recordId;
    private String objectName;
    private String fieldName;

    public CustomRichTextController() {
        try {
            Map<String, String> params = ApexPages.currentPage().getParameters();

            recordId   = params.get('id');
            objectName = params.get('objectName');
            fieldName  = params.get('fieldName');

            if (recordId == null || String.isBlank(objectName) || String.isBlank(fieldName)) {
                richTextHtml = '';
                saveResult = 'INIT ERROR: 파라미터 누락';
                return;
            }

            Type t = Type.forName(objectName);
            if (t == null) {
                richTextHtml = '';
                saveResult = 'INIT ERROR: invalid objectName';
                return;
            }

            String soql =
                    'SELECT ' + fieldName +
                            ' FROM ' + objectName +
                            ' WHERE Id = :recordId LIMIT 1';

            SObject rec = Database.query(soql);

            Object v = rec.get(fieldName);
            richTextHtml = (v == null) ? '' : String.valueOf(v);

        } catch (Exception e) {
            richTextHtml = '';
            saveResult = 'INIT ERROR: ' + e.getMessage();
        }
    }

    // [DEPRECATED] VF 내부 저장 버튼용. LWC postMessage 방식(saveRichText)으로 대체됨.
    // public PageReference save() {
    //     try {
    //         Type t = Type.forName(objectName);
    //         if (t == null) {
    //             saveResult = 'ERROR: invalid objectName';
    //             return null;
    //         }
    //         SObject sObj = (SObject)t.newInstance();
    //         sObj.put('Id', recordId);
    //         sObj.put(fieldName, richTextHtml);
    //         update sObj;
    //         saveResult = 'OK: 저장 완료';
    //     } catch (Exception e) {
    //         saveResult = 'ERROR: ' + e.getMessage();
    //     }
    //     return null;
    // }

    // =========================================================
    // ✅ LWC 저장2 버튼: postMessage로 받은 HTML을 저장
    // =========================================================
    @AuraEnabled
    public static String saveRichText(Id recordId, String objectApiName, String fieldApiName, String htmlContent) {
        try {
            Type t = Type.forName(objectApiName);
            if (t == null) {
                return 'ERROR: invalid objectName';
            }

            SObject sObj = (SObject)t.newInstance();
            sObj.put('Id', recordId);
            sObj.put(fieldApiName, htmlContent);

            update sObj;

            return 'OK: 저장 완료';
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    // =========================================================
    // ✅ LWC에서 사용: 오브젝트/필드 라벨 가져오기
    // =========================================================
    @AuraEnabled(cacheable=true)
    public static String getFieldLabel(String objectApiName, String fieldApiName) {

        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectApiName);
        if (sType == null) return null;

        Schema.SObjectField f = sType.getDescribe().fields.getMap().get(fieldApiName);
        if (f == null) return null;

        // 사용자 언어/번역 적용 라벨
        return f.getDescribe().getLabel();
    }
}