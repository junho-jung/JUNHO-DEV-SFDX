/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class Util_MapUtil {

    public Boolean isBlank(Map<String, Object> targetMap){
        return (targetMap == null || targetMap.isEmpty()) ? true : false;
    }

    public Boolean isBlank(Map<Decimal, Object> targetMap){
        return (targetMap == null || targetMap.isEmpty()) ? true : false;
    }

}