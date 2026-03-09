/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-02      jh.jung           Created
*/
public class InterfaceFactory {

    public class FactoryException extends Exception {}

    // ★ [테스트용 Hook] 테스트 코드에서 가짜 메타데이터를 주입하기 위한 변수
    @TestVisible private static InterfaceConfig__mdt mockConfig;

    /**
     * @description 인터페이스 ID로 구현체 생성 및 설정 주입
     */
    public static IInterfaceExecutor createInstance(String interfaceId) {

        System.debug('createInstance START');
        // 1. 설정 조회 (테스트면 mockConfig 사용, 아니면 실제 DB 조회)
        InterfaceConfig__mdt config;
        if (Test.isRunningTest() && mockConfig != null) {
            config = mockConfig;
        } else {
            config = InterfaceConfig__mdt.getInstance(interfaceId);
        }

        if (config == null) {
            throw new FactoryException('Interface Config Not Found: ' + interfaceId);
        }

        // 2. 활성화 여부 체크 (운영자가 긴급하게 끌 수 있음)
        if (!config.isActive__c) {
            throw new FactoryException('Interface is Inactive: ' + interfaceId);
        }

        // 3. 클래스 로드 (동적 바인딩)
        Type t = Type.forName(config.ImplementationClassName__c);
        if (t == null) {
            throw new FactoryException('Implementation Class Not Found: ' + config.ImplementationClassName__c);
        }

        // 4. 객체 생성
        Object obj = t.newInstance();
        if (!(obj instanceof IInterfaceExecutor)) {
            throw new FactoryException('Class does not implement IInterfaceExecutor: ' + config.ImplementationClassName__c);
        }

        // 5. 설정 주입 (여기서 InterfaceHandler 초기화까지 연쇄적으로 일어남)
        IInterfaceExecutor instance = (IInterfaceExecutor) obj;
        instance.configure(config);

        System.debug(config);
        System.debug(instance);

        return instance;
    }
}