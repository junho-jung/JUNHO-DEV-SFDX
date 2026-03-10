/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public with sharing class UtilRelatedListParameters {

    @AuraEnabled public String recordId {get;set;}
    @AuraEnabled public String currentObjectApi {get;set;}
    @AuraEnabled public String currentObjectFields {get;set;}
    @AuraEnabled public String targetObjectApi {get;set;}
    @AuraEnabled public String fields {get;set;}
    @AuraEnabled public String condition {get;set;}
    @AuraEnabled public String sortedBy {get;set;}
    @AuraEnabled public String sortedDirection {get;set;}
    @AuraEnabled public String limitCount {get;set;}
    @AuraEnabled public Boolean isWithOutSharing {get;set;}
    @AuraEnabled public Boolean needAccessCheck {get;set;}
    @AuraEnabled public Boolean applyApprovalLock {get;set;}
    @AuraEnabled public Boolean isPhone {get;set;}
    @AuraEnabled public Boolean countOnly {get;set;}

    //@AuraEnabled public String viewAllTargetObjectApi {get;set;}
    //@AuraEnabled public String viewAllTargetFieldApi {get;set;}
    
}