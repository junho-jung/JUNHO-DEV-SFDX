/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public with sharing class UtilSObject {

    /**
     * @description SObject에서 해당 필드를 추출하여 String으로 변환
     * @param sObj SObject API
     * @param fieldApi Field API
     *
     * @return String
     */
    public String toString(SObject sObj, String fieldApi) {
        Object value = sObj.get(fieldApi);
        return Core.Object2.toString(value);
    }
}