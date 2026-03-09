/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-02      jh.jung           Created
*/
@IsTest
public class TestInterfaceBatchImpl extends InterfaceBatch {

    // 테스트 제어용 플래그
    public static Boolean failInStart = false;
    public static Boolean failInBefore = false;

    public TestInterfaceBatchImpl() {
        super();
        this.setResponseType(null); // Untyped Map
    }

    // Start
    protected override Database.QueryLocator startBatch(Database.BatchableContext BC) {
        if (failInStart) throw new CalloutException('Start Error Triggered');
        return Database.getQueryLocator([SELECT Id, Name FROM Account ORDER BY Name]);
    }

    // Before
    protected override Object before(Database.BatchableContext BC, List<SObject> scope) {
        if (failInBefore) {
            throw new CalloutException('Before Error Triggered');
        }

        List<String> names = new List<String>();
        for (SObject s : scope) {
            names.add((String)s.get('Name'));
        }
        return new Map<String, Object>{'names' => names};
    }

    // After
    protected override void after(InterfaceHandler.ReturnCls rc) {
        System.debug('Batch After Hook: ' + rc.responseObject);
    }

    // Finish
    protected override void finishBatch(Database.BatchableContext BC) {
        System.debug('Batch Finished');
    }
}