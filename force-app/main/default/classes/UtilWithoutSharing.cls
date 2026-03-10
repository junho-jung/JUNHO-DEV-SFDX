/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public with sharing class UtilWithoutSharing {

    /**
     * @description SObject 조회 및 반환
     * @param query {String} 조회 쿼리문
     * @param bindMap {String} 조회 쿼리문
     * @param accessLevel {String} 조회 쿼리문
     * @return records {List<SObject>} 조회된 SObject 목록
     */
    public static List<SObject> getQueryWithBinds(String query, Map<String, Object> bindMap, AccessLevel accessLevel) {
        if (String.isBlank(query)) {
            return new List<SObject>();
        }
        //List<SObject> result = Database.queryWithBinds(query, bindMap, accessLevel);
        return Database.queryWithBinds(query, bindMap, accessLevel);
    }

}