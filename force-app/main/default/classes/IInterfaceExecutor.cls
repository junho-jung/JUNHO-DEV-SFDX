/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-02      jh.jung           Created
*/
public interface IInterfaceExecutor {

    /**
     * @description Factory에서 메타데이터 설정을 주입할 때 호출
     */
    void configure(InterfaceConfig__mdt config);

    /**
     * @description 공통 실행 메소드
     * @return RealTime은 ReturnCls, Batch는 JobId 등을 리턴하기 위해 Object 사용
     */
    Object call();

    // ✅ 표준화된 요청 객체를 받아 실행하는 메서드
    Object call(Object requestData);

    /**
     * @description 공통 헤더 추가 (형변환 없이 호출 가능하도록 승격)
     */
    void addHeader(String key, String value);

    /**
     * @description 공통 쿼리 파라미터 추가 (형변환 없이 호출 가능하도록 승격)
     */
    void addQueryParam(String key, String value);
}