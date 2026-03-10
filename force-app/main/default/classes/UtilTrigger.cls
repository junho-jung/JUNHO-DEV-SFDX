/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilTrigger {

    /** Whether Test or not */
    private final static Boolean IS_TEST = Test.isRunningTest();

    public static Boolean IS_DEPLOY = false;

    public static Boolean IS_UNIT_TEST = false;

    private final static String ALL_TRIGGER_INACTIVE = 'All the Triggers are inactive. Please check the Org Setting.';
    private final static String PROFILE_TRIGGER_INACTIVE = 'The Trigger is inactive for this Profile';

    /**
     * @description 트리거 호출 코드
     */
    public void run() {

        // 트리거 전체 비활성화 된 경우
        if(!Core.Org2.ORG_SETTING.IsTriggerActive__c){
            warning(ALL_TRIGGER_INACTIVE);
            return;
        }

        // 현재 사용자 Profile 에 대해 비활성화 된 경우
        if(!Core.Org2.INSTANCE_SETTING.IsTriggerActive__c) {
            warning(PROFILE_TRIGGER_INACTIVE);
            return;
        }

        // 트리거 대상이 되는 Object
        String targetObjectApi = IS_UNIT_TEST ? 'Account' : (IS_DEPLOY ? 'Test__c' : (String.valueOf((Trigger.new != null ? Trigger.new : Trigger.old).getSObjectType())));

        TriggerHandler__mdt handler = TriggerHandler__mdt.getAll().get(targetObjectApi.replace('__c', '_c').replace('__e', '_e'));

        // 핸들러가 없는 경우
        if(!IS_UNIT_TEST && !IS_DEPLOY && handler == null){
            throw new HandledException('There is no trigger setting for this object' + targetObjectApi);
        }else if(!handler.IsActive__c){
            return;
        }

        System.debug(LoggingLevel.INFO, '==================== ' + handler?.SObject__c + ' - ' + handler?.Handler__c + ' ===============================');

        // 핸들러 instance 생성
        //test class 에서 트리거를 안타서 아래와 같이 수정
        ITriggerHandler instance = (ITriggerHandler)Type.forName('', handler.Handler__c).newInstance();
        if(instance != null) instance.run();
    }

    private static void warning(String message){
        System.debug(LoggingLevel.WARN, message);
    }

    /**
     * @description return changed List
     * @param oldMap oldMap
     * @param newMap newMap
     * @param targetFieldList target Field List - List<String>
     *
     * @return List<SObject>
     */
    public List<SObject> getChangedList(Map<Id, SObject> oldMap, Map<Id, SObject> newMap, List<String> targetFieldList) {

        List<SObject> changedList = new List<SObject>();
        for (SObject newOne : newMap.values()) {
            SObject oldOne = oldMap.get(newOne.Id);

            for (String sourceField : targetFieldList) {
                if (oldOne.get(sourceField) == newOne.get(sourceField)) continue;
                changedList.add(newOne);
            }
        }
        return changedList;
    }

    /**
     * @description return changed List
     * @param oldMap oldMap
     * @param newMap newMap
     * @param targetFieldSet target Field List - Set<String>
     *
     * @return List<SObject>
     */
    public List<SObject> getChangedList(Map<Id, SObject> oldMap, Map<Id, SObject> newMap, Set<String> targetFieldSet) {
        List<String> targetFieldList = new List<String>();
        targetFieldList.addAll(targetFieldSet);
        return getChangedList(oldMap, newMap, targetFieldList);
    }

    /**
     * @description return changed List
     * @param oldMap oldMap
     * @param newMap newMap
     * @param targetField target Field List - String
     *
     * @return List<SObject>
     */
    public List<SObject> getChangedList(Map<Id, SObject> oldMap, Map<Id, SObject> newMap, String targetField) {
        return getChangedList(oldMap, newMap, new List<String>{
            targetField
        });
    }
}