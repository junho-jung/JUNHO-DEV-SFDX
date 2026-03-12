/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
/**
 * 모든 보안 처리 클래스가 구현해야 할 공통 인터페이스
 */
global interface ISecurityAction {
    void execute(String payloadJson);
}