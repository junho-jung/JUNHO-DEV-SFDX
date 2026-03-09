/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class Util_ObjectUtil {

    /**
     * @description Object -> String
     * @param obj Object
     *
     * @return String
     */
    public String toString(Object obj) {
        return obj == null ? null : String.valueOf(obj);
    }

}