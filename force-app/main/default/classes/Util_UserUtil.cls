/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class Util_UserUtil {

    /** Whether Test or not */
    //private final Boolean IS_TEST = Test.isRunningTest();

    /**
     * @description 현재 레코드에 대한 유저 권한 확인
     * @param userId User Id
     * @param recordId Record Id
     *
     * @return UserRecordAccess
     */
    public AccessCls getRecordAccess(Id userId, Id recordId) {
        return getRecordAccess(userId, new Set<Id>{recordId}).get(recordId);
    }

    /**
     * @description 여러 레코드에 대한 유저 권한 확인
     * @param userId User Id
     * @param recordIdSet Set<Record Id>
     *
     * @return Map<String, UserRecordAccess>
     */
    public Map<String, AccessCls> getRecordAccess(Id userId, Set<Id> recordIdSet) {

        Boolean hasViewAll = checkPermissionViewAll();
        Boolean hasModifyAll = checkPermissionModifyAll();

        Map<String, AccessCls> accessMap = new Map<String, AccessCls>();
        for(UserRecordAccess access : [SELECT RecordId, HasEditAccess, HasReadAccess, HasDeleteAccess, HasTransferAccess, HasAllAccess FROM UserRecordAccess WHERE UserId = :userId AND RecordId IN :recordIdSet]){
            AccessCls ac = new AccessCls();
            ac.HasAllAccess = hasModifyAll || access.HasAllAccess;
            ac.HasEditAccess = hasModifyAll || access.HasEditAccess;
            ac.HasReadAccess = hasModifyAll || hasViewAll || access.HasReadAccess;
            ac.HasDeleteAccess = hasModifyAll || access.HasDeleteAccess;
            ac.HasTransferAccess = hasModifyAll || access.HasTransferAccess;
            accessMap.put(access.RecordId, ac);
        }
        return accessMap;
    }

    /**
     * @description 여러 레코드에 대한 유저 권한 확인
     * @param userId  User Id
     * @param recordList List<SObject>
     *
     * @return Map<String, UserRecordAccess>
     */
    public Map<String, AccessCls> getRecordAccess(Id userId, List<SObject> recordList) {
        System.debug(LoggingLevel.INFO, '==================== Util_UserUtil.getRecordAccess ===============================');
        Set<Id> recordIdSet = new Set<Id>();
        for(SObject record : recordList){
            recordIdSet.add(record.Id);
        }
        return getRecordAccess(userId, recordIdSet);
    }

    /**
     * @description 현재 사용자의 ViewAllData 권한 확인
     * @return Boolean
     */
    public Boolean checkPermissionViewAll(){
        return FeatureManagement.checkPermission('ViewAllData');
    }

    /**
     * @description 현재 사용자의 ModifyAllData 권한 확인
     * @return Boolean
     */
    public Boolean checkPermissionModifyAll(){
        return FeatureManagement.checkPermission('hasModifyAll');
    }

    public class AccessCls {
        @AuraEnabled public Boolean HasEditAccess;
        @AuraEnabled public Boolean HasReadAccess;
        @AuraEnabled public Boolean HasDeleteAccess;
        @AuraEnabled public Boolean HasTransferAccess;
        @AuraEnabled public Boolean HasAllAccess;
        @AuraEnabled public String RecordId;
        @AuraEnabled public String userId;
    }




    /**
     * @description 유저 정보 반환
     * @param userId User Id
     *
     * @return User
     */
    public User getUserInfo(String userId){
        String objApi = 'User';
        // todo 수정 필요
        //List<String> fieldList = Core.Query2.getAll(objApi);
        List<String> fieldList = new List<String>();
        fieldList.addAll(new Set<String>{'Profile.Name', 'UserRole.Name'});
        return Database.query('SELECT ' +  String.join(fieldList, ',') + ' FROM ' + objApi + ' WHERE Id = :userId');
    }

    /*global Boolean checkPartner(User userId){
        System.debug(LoggingLevel.INFO, '==================== LGE_OpportunityTeamMemberButtons.checkPartner ===============================');
        return String.isNotBlank(usr.ContactId);
    }*/

    /**
     * @description 사용자가 사용 가능한 언어의 목록을 반환한다
     * @return List<LanguageCls>
     */
    public List<LanguageCls> getUserLanguage(){
        Schema.DescribeFieldResult fieldResult = User.LanguageLocaleKey.getDescribe();
        List<LanguageCls> lcList = new List<LanguageCls>();
        for(Schema.PicklistEntry entry : fieldResult.getPicklistValues()){
            LanguageCls lc = new LanguageCls();
            lc.label = entry.getLabel();
            lc.value = entry.getValue();
            lc.isActive = entry.isActive();
            lc.isDefaultValue = entry.isDefaultValue();
            lcList.add(lc);
        }
        return lcList;
    }

    public class LanguageCls {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean isDefaultValue;
    }

}