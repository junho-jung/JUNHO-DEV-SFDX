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
private class InterfaceFactoryTest {

    // 팩토리가 생성할 가짜 구현 클래스 (Inner Class)
    // 주의: Type.forName이 Inner Class를 찾으려면 'OuterClass.InnerClass' 형태여야 함.
    // 하지만 Test 클래스 내부의 Inner Class는 동적 생성이 까다로울 수 있음.
    // 따라서 실패 케이스 위주로 테스트하거나, 실제 존재하는 아무 클래스(예: InterfaceFactoryTest 자체)를 타겟으로 함.

    // 테스트용 Stub 구현체
    public class TestExecutor implements IInterfaceExecutor {
        public void configure(InterfaceConfig__mdt config) {}
        public Object execute() { return 'DONE'; }
        public void addHeader(String k, String v) {}
        public void addQueryParam(String k, String v) {}
        public Object call(Object requestData) { return 'DONE'; }
        public Object call() { return 'DONE'; }
    }

    @IsTest
    static void testCreateInstanceSuccess() {
        // Given
        // 가짜 메타데이터 생성 (ImplementationClassName__c에 위 Stub 클래스 지정)
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => 'TEST_IF',
            'ImplementationClassName__c' => 'InterfaceFactoryTest.TestExecutor', // 현재 테스트 클래스 내부의 Stub
            'isActive__c' => true
        };
        InterfaceConfig__mdt mock = (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);

        // Factory에 Mock 주입
        InterfaceFactory.mockConfig = mock;

        // When
        IInterfaceExecutor instance = InterfaceFactory.createInstance('TEST_IF');

        // Then
        System.assertNotEquals(null, instance, '인스턴스가 생성되어야 함');
        System.assertEquals('DONE', instance.call(), 'execute가 정상 동작해야 함');
    }

    @IsTest
    static void testConfigNotFound() {
        // Given
        InterfaceFactory.mockConfig = null; // 설정 없음

        // When & Then
        try {
            InterfaceFactory.createInstance('UNKNOWN_ID');
            System.assert(false, '존재하지 않는 ID는 에러가 나야 함');
        } catch (InterfaceFactory.FactoryException e) {
            System.assert(e.getMessage().contains('Config Not Found'));
        }
    }

    @IsTest
    static void testInactiveInterface() {
        // Given
        Map<String, Object> fields = new Map<String, Object>{
            'DeveloperName' => 'TEST_IF',
            'isActive__c' => false // 비활성화
        };
        InterfaceFactory.mockConfig = (InterfaceConfig__mdt) JSON.deserialize(JSON.serialize(fields), InterfaceConfig__mdt.class);

        // When & Then
        try {
            InterfaceFactory.createInstance('TEST_IF');
            System.assert(false, '비활성 인터페이스는 에러가 나야 함');
        } catch (InterfaceFactory.FactoryException e) {
            System.assert(e.getMessage().contains('Inactive'));
        }
    }
}