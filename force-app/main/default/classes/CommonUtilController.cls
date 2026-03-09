/**
* @Author            : jh.jung
* @Description 		 : 공통Util 함수 Controller
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
public without sharing class CommonUtilController {

    /**
     * @param           paramTime paramTime type
     * @param           type A, B, C
     * @description     Type에 따른 날짜형식 Return
     * @return          String formatDate
     */
    public static String formatDate(Datetime paramTime, String type) {
        String formatDate = null;

        String year = String.valueOf(paramTime.year());
        String month = String.valueOf(paramTime.month()).leftPad(2, '0');
        String day = String.valueOf(paramTime.day()).leftPad(2, '0');
        switch on type.toUpperCase() {
            when 'A' {
                formatDate = year + '-' + month + '-' + day;
            }
            when 'B' {
                formatDate = year + '_' + month + '_' + day;
            }
            when 'C' {
                formatDate = year + month + day;
            }
        }

        return formatDate;
    }

    public enum ReturnType {
        DateTimeType, DateType
    }
    public static Object stringToDate(String paramDate) { return stringToDate(paramDate, ReturnType.DateType); }
    public static Object stringToDate(String paramDate, ReturnType returnType) {
        Object result;

        Integer year = Integer.valueOf(paramDate.substring(0, 4));
        Integer month = Integer.valueOf(paramDate.substring(4, 6));
        Integer day = Integer.valueOf(paramDate.substring(6, 8));

        switch on returnType.name() {
            when 'DateTimeType' { result = Datetime.newInstance(year, month, day, 0, 0, 0); }
            when else           { result = Date.newInstance(year, month, day); }
        }

        return result;
    }

    /**
     * @param           url URL 주소
     * @param           key 추출하고자하는 Key
     * @description     URL 주소중 Key에 해당하는 값 추출
     * @return          String Value
     */
    public static String extractStringFromURL(String url, String key) {
        System.debug(EncodingUtil.urlDecode(url, 'UTF-8'));
        String queryString = url.split('\\?')[1];
        Map<String, String> queryParams = new Map<String, String>();

        // 쿼리 문자열을 &로 분리 후 파라미터 맵에 저장
        for (String param : queryString.split('&')) {
            List<String> keyValue = param.split('=');
            if (keyValue.size() == 2) {
                queryParams.put(keyValue[0], keyValue[1]);
            }
        }

        return queryParams.containsKey(key) ? queryParams.get(key) : null;
    }

    /**
     * @param str       Text
     * @param line      Number of Lines to Return
     * @param size      Text Length
     * @description     str에 대한 size값만큼 1줄에 표기. 넘어갈경우 line만큼 표기
     * @return          String value
     */
    public static String sliceStrLength(String str, Integer line, Integer size) {
        if (str == null) return '';
        String returnStr = '';

        Decimal length = 0;
        Integer index = 1;
        for (Integer i = 0; i < str.length(); i++) {
            String character = str.substring(i, i + 1);
            if (character.isWhitespace()) {
                length += 1;
            } else if (Pattern.matches('[.,]', character)) {
                length += 1;
            } else if (Pattern.matches('[a-z]', character)) {
                length += 1.5;
            } else {
                length += 2;
            }

            if (line > 1) {
                // Line 수만큼 출력
                returnStr += character;
                if (length > size) {
                    if (index == line) {
                        returnStr += '...';
                        break;
                    }
                    index++;
                    length = 0;
                    returnStr += '<->';
                }
            } else {
                // 한라인으로 출력 End
                if (length > size) {
                    returnStr += '...';
                    break;
                } else {
                    returnStr += character;
                }
            }
        }
        return returnStr;
    }

    /**
     * @param objectName    Object Name
     * @param fieldName     Object Field Name
     * @description         Object와 Field명에 대한 PickList 값 Return
     * @return              List<Map<String, String>> value
     */
    public static List<Map<String, String>> getPickList(String objectName, String fieldName) {
        // 정렬기능 추가
        return getPickList(objectName, fieldName, SORT_TYPE.LABEL);
    }
    public static List<Map<String, String>> getPickList(String objectName, String fieldName, SORT_TYPE sortType) {
        return getPickList(objectName, fieldName, sortType, true);
    }
    public static List<Map<String, String>> getPickList(String objectName, String fieldName, SORT_TYPE sortType, Boolean ascending) {
        DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Schema.DescribeFieldResult field = describeResult.fields.getMap().get(fieldName).getDescribe();

        List<Map<String, String>> listPickList = new List<Map<String, String>>();
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            listPickList.add(new Map<String, String>{
                'label' => entry.getLabel(),
                'value' => entry.getValue()
            });
        }
        // 정렬기능 추가
        if(sortType != null) sortMaps(listPickList, sortType, ascending);

        return listPickList;
    }

    /**
     * @param objectName    Object Name
     * @description         Object ListView Return
     * @return              List<Map<String, String>> value
     */
    public static List<Map<String, String>> getListView(String objectName) {
        List<Map<String, String>> listViews = new List<Map<String, String>>();
        for (ListView obj : [
            SELECT Id, Name, DeveloperName
            FROM ListView
            WHERE SobjectType = :objectName
        ]) {
            Map<String, String> listView = new Map<String, String>();

            listView.put('Id', obj.Id);
            listView.put('Name', obj.Name);

            listViews.add(listView);
        }

        return listViews;
    }

    /**
     * @param objectName    Object Name
     * @param fieldName     Object Field Name
     * @description         Object와 Field명에 대한 PickList 값(Only Value) Return
     * @return              Set<String> value
     */
    public static Set<String> getPickListValue(String objectName, String fieldName) {
        DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Schema.DescribeFieldResult field = describeResult.fields.getMap().get(fieldName).getDescribe();

        Set<String> valueList = new Set<String>();
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            valueList.add(entry.getValue());
        }

        return valueList;
    }

    /**
     * @param objectName    Object Name
     * @param fieldName     Object Field Name
     * @param isKeyValue    key - value 설정
     * @description         Object와 Field명에 대한 PickList Map Return
     * @return              Map<String, String> Value
     */
    public static Map<String, String> getPickListMap(String objectName, String fieldName, Boolean isKeyValue) {
        DescribeSObjectResult describeResult = Schema.getGlobalDescribe().get(objectName).getDescribe();
        Schema.DescribeFieldResult field = describeResult.fields.getMap().get(fieldName).getDescribe();

        Map<String, String> infoMap = new Map<String, String>();
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            String key = isKeyValue ? entry.getValue() : entry.getLabel();
            String value = isKeyValue ? entry.getLabel() : entry.getValue();

            infoMap.put(key, value);
        }

        return infoMap;
    }
    public static Map<String, String> getPickListMap(String objectName, String fieldName)       { return getPickListMap(objectName, fieldName, false);  }
    public static Map<String, String> getPickListLabelMap(String objectName, String fieldName)  { return getPickListMap(objectName, fieldName, true);   }

    /**
     * @author th.kim
     * @description Picklist Value 값으로 Label 값 가져오기
     * @param objectName 개체명
     * @param fieldName Picklist 필드명
     * @param picklistValue Picklist Value
     *
     * @return Picklist Label
     */
    public static String getPicklistLabelForLabel(String objectName, String fieldName, String picklistValue) {

        // 객체 및 필드 이름으로 Describe 메타데이터 가져오기
        Schema.DescribeFieldResult fieldDescribe = Schema.getGlobalDescribe()
            .get(objectName)
            .getDescribe()
            .fields.getMap()
            .get(fieldName)
            .getDescribe();

        // 선택목록 값 순회하며 값 찾으면 라벨 반환
        for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
            if (entry.getValue() == picklistValue) {
                return entry.getLabel();
            }
        }

        // 값이 없을 경우 null 반환
        return null;
    }

    /**
     * @param objectName    Object Name
     * @description         Object Name을 기준으로 Field Key값 가져오기
     * @return              List<String> value
     */
    public static List<String> getAllFields(String objectName) {
        List<String> listFields = new List<String>();

        SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Map<String, Schema.SObjectField> mapFields = objType.getDescribe().fields.getMap();

        for (String key : mapFields.keySet()) {
            listFields.add(String.valueOf(mapFields.get(key)));
        }
        return listFields;
    }

    /**
     * @param collection    List<String> or Set<String>
     * @description         Where 동적쿼리를 위해 collection타입 String으로 변경
     * @return              String value
     */
    public static String joinedString(Object collection) {
        List<String> returnList = returnList(collection);

        return '(\'' + String.join(returnList, '\',\'') + '\')';
    }

    public static List<String> returnList(Object collection) {
        List<String> resultList = new List<String>();

        if (collection instanceof Iterable<Object>) {
            for (Object strings : (Iterable<Object>) collection) {
                resultList.add(String.valueOf(strings));
            }
        }

        return resultList;
    }

    /**
     * @param objList       Object Record List
     * @param labelList     Join할 Label List
     * @param joinKey       Join될 Key값
     * @description         sfds
     * @return              Map<String, List<SObject>> Value
     */
    public static Map<String, List<SObject>> getObjectMapJoin(List<SObject> objList, List<String> labelList, String joinKey) {
        Map<String, List<SObject>> objKeyListMap = new Map<String, List<SObject>>();
        for (SObject obj : objList) {
            List<String> valueList = new List<String>();
            for (String label : labelList) {
                String value = String.valueOf(obj.get(label));
                valueList.add(value);
            }

            String returnKey = '';
            for (Integer i = 0; i < valueList.size(); i++) {
                returnKey += valueList.get(i);
                if (i != valueList.size() - 1) returnKey += joinKey;
            }
            List<SObject> objectList = objKeyListMap.containsKey(returnKey) ? objKeyListMap.get(returnKey) : new List<SObject>();
            objectList.add(obj);
            objKeyListMap.put(returnKey, objectList);
        }
        return objKeyListMap;
    }

    /**
     * @param targetList    Object RecordList
     * @param type          C, U의 값(insert, update)
     * @param isAll         All or Nothing
     * @descrption          C, U의 결과 Return
     * @return              Map<String, Map<String, Object>>
     */
    public static Map<String, Map<String, Object>> applyObject(List<SObject> targetList, String type, Boolean isAll) {
        Map<String, Map<String, Object>> resultMap = new Map<String, Map<String, Object>>();
        Map<String, Object> successMap = new Map<String, Object>();
        Map<String, Object> failMap = new Map<String, Object>();

        Database.SaveResult[] results;
        try {
            switch on type.toUpperCase() {
                when 'INSERT' {
                    results = Database.insert(targetList, isAll);
                }
                when 'UPDATE' {
                    results = Database.update(targetList, isAll);
                }
            }

            for (Database.SaveResult result : results) {
                if (result.success) {
                    successMap.put(result.getId(), NULL);
                } else {
                    failMap.put(result.getId(), result.getErrors());
                }
            }
        } catch (DmlException e) {
            failMap.put('Debug', e.getMessage());
        }

        resultMap.put('SUCCESS', successMap);
        resultMap.put('FAIL', failMap);

        return resultMap;
    }

    public static Map<String, Map<String, Object>> applyObject(List<SObject> targetList, String type) {
        return applyObject(targetList, type, false);
    }

    public static String buildQuery(String selectFields, String fromObject, String whereConditions) {
        return buildQuery(selectFields, fromObject, whereConditions, 'CreatedDate DESC');
    }

    /**
     * @author th.kim
     * @description 동적 String 쿼리 만들기
     * @param selectFields SELECT 할 필드
     * @param fromObject FROM 개체
     * @param whereConditions WHERE 조건
     * @param orderBy ORDER BY 조건
     *
     * @return String 쿼리
     */
    public static String buildQuery(String selectFields, String fromObject, String whereConditions, String orderBy) {
        List<String> queryList = new List<String>();

        queryList.add('SELECT ' + selectFields);    // SELECT 부분 추가
        queryList.add('FROM ' + fromObject);        // FROM 부분 추가

        // WHERE 조건이 있으면 추가
        if (String.isNotBlank(whereConditions)) queryList.add('WHERE ' + whereConditions);
        if (String.isNotBlank(orderBy)) queryList.add('ORDER BY ' + orderBy);

        // 쿼리 문자열 결합
        return String.join(queryList, ' ');
    }

    /**
     * @author th.kim
     * @description where 조건문 Dynamic 쿼리로 생성
     * @param filterMap where 조건문 {apiName => value}
     *
     * @return where 조건문 string query
     */
    public static String buildWhereConditions(Map<String, Object> filterMap) {

        List<String> whereConditionList = new List<String>();

        // 필터 맵 순회
        for (String key : filterMap.keySet()) {
            Object value = filterMap.get(key);
            if (String.isNotBlank(String.valueOf(value))) {
                String valueStr = String.valueOf(value).trim().toUpperCase();
                if (valueStr == '!= NULL') {
                    // '!= NULL' 조건 처리
                    whereConditionList.add(key + ' != NULL');
                } else if (valueStr == '= NULL') {
                    // '= NULL' 조건 처리
                    whereConditionList.add(key + ' = NULL');
                } else if (value instanceof Boolean) {
                    // Boolean 값 처리
                    whereConditionList.add(key + ' = ' + String.valueOf(value));
                } else if (valueStr.startsWith('>') || valueStr.startsWith('<') || valueStr.startsWith('=')) {
                    // 비교 연산자 처리
                    whereConditionList.add(key + ' ' + valueStr);
                } else {
                    // 문자열 값 처리
                    whereConditionList.add(key + ' = \'' + String.escapeSingleQuotes(String.valueOf(value)) + '\'');
                }
            }
        }

        // 조건이 존재하면 AND로 결합
        String whereConditions = whereConditionList.isEmpty() ? '' : String.join(whereConditionList, ' AND ');

        return whereConditions; // 완성된 WHERE 절 반환

    }

    /**
     * @author th.kim
     * @description fifteenDigit의 데이터가 15자리의 Id 값이면 18자리의 Id 값으로 리턴, 아닐 시 null 리턴
     * @param fifteenDigit 15자리 Id 값
     *
     * @return 18자리 Id 값 || null
     */
    public static String convert15to18DigitId(String fifteenDigit) {
        if (String.isNotBlank(fifteenDigit) && fifteenDigit.length() == 15) {
            return (Id) fifteenDigit;
        } else {
            return null;
        }
    }

    /**
     * @param str       String Text
     * @description     PickList의 APIName이 같아야 할 경우(ex, SAP 코드체계), '__' + 숫자를 통해서 중복 Validation우회
     * @return          String Value
     */
    public static String sliceUBarBefore(String str) {
        return str != null
            ? str.contains('__') ? str.substringBefore('__') : str
            : null;
    }

    /**
     * @param inputDate     기준 날짜
     * @return              주말 : true, 평일 : false
     */
    public static Boolean isWeekend(Date inputDate) {
        Date startOfWeek = inputDate.toStartOfWeek();
        Integer dayOfWeek = startOfWeek.daysBetween(inputDate) + 1;

        return dayOfWeek == 7 || dayOfWeek == 1 ? true : false;
    }

    /**
     * @param mapList       정렬필요 List
     * @param sortType      Label, Value 기준값
     * @param ascending     정렬순서
     * @description         sortType기준으로 ascending값에 따른 mapList 정렬
     */
    public static void sortMaps(List<Map<String, String>> mapList, SORT_TYPE sortType, Boolean ascending) {
        List<MapWrapper> wrapperList = new List<MapWrapper>();
        for (Map<String, String> objMap : mapList) {
            wrapperList.add(new MapWrapper(objMap, sortType, ascending));
        }
        wrapperList.sort();
        mapList.clear();

        for (MapWrapper wrapper : wrapperList) {
            mapList.add(wrapper.mapValue);
        }
    }

    public enum SORT_TYPE {
        LABEL, VALUE
    }
    public class MapWrapper implements Comparable {
        private Map<String, String> mapValue;
        private String label;
        private Boolean ascending;

        public MapWrapper(Map<String, String> mapValue, SORT_TYPE sortType, Boolean ascending) {
            this.mapValue = mapValue;
            this.label = sortType == SORT_TYPE.LABEL ? 'label' : 'value';
            this.ascending = ascending;
        }

        public Integer compareTo(Object obj) {
            MapWrapper otherWrapper = (MapWrapper) obj;
            Integer result = this.mapValue.get(label).compareTo(otherWrapper.mapValue.get(label));
            return ascending ? result : -result;
        }
    }

    /**
     * @param sObjectList       정렬한 SObject List
     * @param fieldName         정렬기준 필드명
     * @param ascending         오름정렬 여부
     */
    public static void sortSObjectList(List<SObject> SObjectList, String fieldName, Boolean ascending) {
        List<SObjectWrapper> wrapperList = new List<SObjectWrapper>();
        for (SObject obj : SObjectList) {
            wrapperList.add(new SObjectWrapper(obj, fieldName, ascending));
        }
        wrapperList.sort();
        SObjectList.clear();

        for (SObjectWrapper wrapper : wrapperList) {
            SObjectList.add(wrapper.obj);
        }
    }

    /**
     * @param startTime         시작시간
     * @param delaySeconds      Delay 시간
     * @description             현재시간을 기준으로 delaySeconds만큼 delay
     */
    public static void delayTime(Datetime startTime, Integer delaySeconds) {
        while(Datetime.now().getTime() - startTime.getTime() < delaySeconds * 1000);
    }

    public class NotificationWrap {
        public String title;
        public String body;
        public String notificationTypeId;
        public String senderId;
        public String targetId;
        public Set<String> userIdSet;
        public String pageRef {get; set;}

        //초기버전 생성자 (기존에 활용중이므로 유지 필수.)
        public NotificationWrap(String title, String body, String notificationTypeId, String senderId, String targetId, Set<String> userIdSet) {
            this.title = title;
            this.body = body;
            this.notificationTypeId = notificationTypeId;
            this.senderId = senderId;
            this.targetId = targetId;
            this.userIdSet = userIdSet;
        }
    }

    /**
     * @author th.kim
     * @description 사용자 정의 알림 전송
     * @param notificationWrap 알림 데이터
     */
    public static void sendNotification(NotificationWrap notificationWrap) {

        if (
            (notificationWrap == null || notificationWrap.userIdSet == null || notificationWrap.userIdSet.isEmpty()) ||
                (notificationWrap.targetId == null && notificationWrap.pageRef == null)
        ) {
            throw new QueryException('필수 알림 데이터 누락');
        }

        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle(notificationWrap.title);
        notification.setBody(notificationWrap.body);
        notification.setNotificationTypeId(notificationWrap.notificationTypeId);
        notification.setSenderId(notificationWrap.senderId);
        if (notificationWrap.targetId != null) notification.setTargetId(notificationWrap.targetId);
        if (notificationWrap.pageRef != null) notification.setTargetPageRef(notificationWrap.pageRef);
        notification.send(notificationWrap.userIdSet);
    }

    public class SObjectWrapper implements Comparable {
        private SObject obj;
        private String fieldName;
        private Boolean ascending;

        public SObjectWrapper(SObject obj, String fieldName, Boolean ascending) {
            this.obj = obj;
            this.fieldName = fieldName;
            this.ascending = ascending;
        }

        public Integer compareTo(Object obj) {
            SObjectWrapper otherWrapper = (SObjectWrapper) obj;

            Object objValue = this.obj.get(fieldName);
            Object objOtherValue = otherWrapper.obj.get(fieldName);

            Integer result;
            if (objValue instanceof Decimal) {
                Integer scaledObjValue = Integer.valueOf((Double) objValue * 100);
                Integer scaledObjOtherValue = Integer.valueOf((Double) objOtherValue * 100);

                result = scaledObjValue - scaledObjOtherValue;
            } else if (objValue instanceof Datetime) {
                Long timeObjValue = Datetime.valueOf(objValue).getTime();
                Long timeOtherObjValue = Datetime.valueOf(objOtherValue).getTime();

                result = Integer.valueOf((timeObjValue - timeOtherObjValue) / 1000);
            } else if (objValue instanceof Date) {
                result = Date.valueOf(objValue).daysBetween(Date.valueOf(objOtherValue));
            } else {
                result = String.valueOf(objValue).compareTo(String.valueOf(objOtherValue));
            }

            return ascending ? result : -result;
        }
    }

    /**
     * @author                  iinokim@solomontech.net
     * @description             [BB-00000305] 동적 SOQL 쿼리 실행 (재사용 가능한 범용 메소드)
     * @param selectFields      SELECT할 필드 (예: 'Id, Name, Attribute1__c')
     * @param sObjectName       조회할 Object API Name (예: 'ConfigDetail__c')
     * @param whereConditions   WHERE 조건 (예: 'Status__c = \'Active\' AND Name != NULL')
     * @return                  List<SObject> - 쿼리 결과
     */
    public static List<SObject> queryRecords(String selectFields, String sObjectName, String whereConditions) {
        return queryRecords(selectFields, sObjectName, whereConditions, null);
    }

    /**
     * @author                  iinokim@solomontech.net
     * @description             [BB-00000305] 동적 SOQL 쿼리 실행 (재사용 가능한 범용 메소드 - ORDER BY 포함)
     * @param selectFields      SELECT할 필드 (예: 'Id, Name, Attribute1__c')
     * @param sObjectName       조회할 Object API Name (예: 'ConfigDetail__c')
     * @param whereConditions   WHERE 조건 (예: 'Status__c = \'Active\' AND Name != NULL')
     * @param orderBy           ORDER BY 조건 (예: 'Name ASC, CreatedDate DESC')
     * @return                  List<SObject> - 쿼리 결과
     */
    public static List<SObject> queryRecords(String selectFields, String sObjectName, String whereConditions, String orderBy) {
        String query = String.isNotBlank(orderBy)
            ? buildQuery(selectFields, sObjectName, whereConditions, orderBy)
            : buildQuery(selectFields, sObjectName, whereConditions);
        System.debug('Executing Query: ' + query);
        return Database.query(query);
    }
}