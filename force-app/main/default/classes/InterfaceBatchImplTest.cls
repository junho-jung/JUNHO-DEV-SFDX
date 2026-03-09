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
public class InterfaceBatchImplTest extends InterfaceBatch {

    // 테스트 제어용 플래그 (static으로 선언하여 외부에서 제어)
    public static Boolean failInStart = false;
    public static Boolean failInBefore = false;
    public static Boolean failInFinish = false; // [추가] Finish 에러 테스트용

    // 기본 생성자
    public InterfaceBatchImplTest() {
        super();
        this.setResponseType(null);
    }

    // [추가] Legacy 생성자 테스트용 (runOnError 옵션 등)
    public InterfaceBatchImplTest(String name, Boolean runOnError) {
        super(name, null, runOnError);
    }

    // Start
    protected override Database.QueryLocator startBatch(Database.BatchableContext BC) {
        if (failInStart) throw new CalloutException('Start Error Triggered');
        // 정렬 순서를 명시하여 청크 테스트 시 순서 보장
        return Database.getQueryLocator([SELECT Id, Name FROM Account ORDER BY Name ASC]);
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
        // [추가] Finish 단계 에러 시뮬레이션
        if (failInFinish) {
            throw new CalloutException('Finish Error Triggered');
        }
        System.debug('Batch Finished');
    }
}