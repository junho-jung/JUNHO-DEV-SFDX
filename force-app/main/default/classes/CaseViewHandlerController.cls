/*
@File Name              CaseViewHandlerController.cls
@Description            description   
@Author                 jh.jung
@Last Modified By       blacktick@solomontech.net
@Create Date            2024-08-02
@Modified Log :
    Ver     | Date                  | Author        | Modification
    0.1     | 2024-08-02            | jh.jung       | Creating...
*/
public with sharing class CaseViewHandlerController {

//    recordId : this.recordId, model: this.model, sn: this.sn, warranty: this.warranty, consoleInspectionContent: this.consoleInspectionContent, others: this.others
    @AuraEnabled
    public static Boolean doSaveCase(String recordId, String model, String sn, String warranty, String consoleInspectionContent, String others) {
        
        return true;
    }

    @AuraEnabled
    public static Case initCaseInfo(String recordId) {
        return [SELECT Account.Name, Owner.Name, Model__c, InstallationDate__c, SN__c, Warranty__c, UserCreateDate__c, UserCloseDate__c, Others__c, Description, Contact.Name, Contact.Title, Contact.Department
        FROM Case
        WHERE Id = :recordId];
    }

    @AuraEnabled
    public static List<String> initRadioInfo(String recordId) {
//        Case initCase = [SELECT Result_D1__c,
//                Result_D2__c,
//                Result_D3__c,
//                Result_D4__c,
//                Result_D5__c,
//                Result_D6__c,
//                Result_D7__c,
//                Result_D8__c,
//                Result_D9__c,
//                Result_D10__c,
//                Result_D11__c
//        FROM Case
//        WHERE Id = :recordId
//        LIMIT 1];
//
//        List<String> initRadio = new List<String>();
//        initRadio.add(String.valueOf(initCase.Result_D1__c));
//        initRadio.add(String.valueOf(initCase.Result_D2__c));
//        initRadio.add(String.valueOf(initCase.Result_D3__c));
//        initRadio.add(String.valueOf(initCase.Result_D4__c));
//        initRadio.add(String.valueOf(initCase.Result_D5__c));
//        initRadio.add(String.valueOf(initCase.Result_D6__c));
//        initRadio.add(String.valueOf(initCase.Result_D7__c));
//        initRadio.add(String.valueOf(initCase.Result_D8__c));
//        initRadio.add(String.valueOf(initCase.Result_D9__c));
//        initRadio.add(String.valueOf(initCase.Result_D10__c));
//        initRadio.add(String.valueOf(initCase.Result_D11__c));
//        return initRadio;
        return new List<String>();
    }

    @AuraEnabled
    public static Boolean doSaveRadio(String recordId, List<String> radioList) {
        System.debug('doSaveCase ::: ');
        System.debug('radioList ::: ' + radioList);
        try {
            if(radioList.isEmpty())
                return true;

            String query = '';
            query += 'SELECT ';
            for (Integer i = 1; i <= Math.min(11, radioList.size()); i++) {
                query += 'Result_D' + String.valueOf(i) + '__c,';
            }
            // 마지막 ',' 삭제
            query = query.substring(0, query.length()-1);
            query += ' FROM Case\n' +
                    ' WHERE Id = :recordId\n' +
                    ' LIMIT 1 ';

            System.debug(query);

            Case updateCase = Database.query(query);

            for (Integer i = 0; i < Math.min(11, radioList.size()); i++) {
                String fieldName = 'Result_D' + (i + 1) + '__c';
                Schema.SObjectField fieldToken = Case.SObjectType.getDescribe().fields.getMap().get(fieldName);
                if (fieldToken != null) {
                    updateCase.put(fieldName, Decimal.valueOf(radioList[i]));
                } else {
                    System.debug('Field ' + fieldName + ' does not exist.');
                }
            }
            System.debug('updateCase ::: ' + updateCase);
            update updateCase;
        } catch (Exception e) {
            System.debug(e.getMessage());
            System.debug(e.getStackTraceString());
        }

        return true;
    }

}