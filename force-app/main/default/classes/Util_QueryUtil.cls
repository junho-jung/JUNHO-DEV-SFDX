/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class Util_QueryUtil {

    /**
     * @description 모든 필드를 포함한 쿼리 String을 반환
     * @param objApi Object API
     *
     * @return String
     */
    public String all(String objApi) {
        String query = 'SELECT ';

        query += String.join(getAll(objApi), ',');
        query += ' FROM ' + objApi;

        return query;
    }

    /**
     * @description 모든 필드 API 리스트 반환
     * @param objApi Object API
     *
     * @return List<String>
     */
    public List<String> getAll(String objApi) {
        List<String> fieldList = new List<String>();
        for (SObjectField field : Core.Schema2.getFieldList(objApi)) {
            fieldList.add(field.getDescribe().name);
        }
        return fieldList;
    }

}