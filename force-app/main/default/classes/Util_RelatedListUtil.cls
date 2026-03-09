/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public abstract with sharing class Util_RelatedListUtil {

    /** Whether Test or not */
    private final static Boolean IS_TEST = Test.isRunningTest();

    /**
     * @description Column 목록 반환
     * @param fields 필드 API 목록
     *
     * @return List<String>
     */
    public virtual List<String> getColumnList(String fields){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getColumnList ===============================');
        List<String> columnList = new List<String>();
        if(String.isNotBlank(fields)) columnList.addAll(fields.deleteWhitespace().split(','));
        return columnList;
    }

    public final Map<String, String> columnMap = new Map<String, String>();
    /**
     * @description 관련 오브젝트 정보 반환
     * @param params Util_RelatedListParameters
     * @param columnList List<String>
     *
     * @return Map<String, Util_RelatedListUtil.RelatedObjectCls>
     */
    public virtual Map<String, Util_RelatedListUtil.RelatedObjectCls> getRelatedObject(Util_RelatedListParameters params, List<String> columnList){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getRelatedObject ===============================');


        // Util_RelatedListParameters params,
        String objApi = params.currentObjectApi,
            relatedObjApi = params.targetObjectApi;


        // 현재 Object + 쿼리 대상 Object
        Set<String> objApiSet = new Set<String>();
        if(String.isNotBlank(objApi)) objApiSet.add(objApi);
        String currentApi = relatedObjApi;
        objApiSet.add(currentApi);

        // Key가 소문자이므로 돌려서 API를 다시 Key로 잡는다
        Map<String, Map<String, Schema.DescribeFieldResult>> objectFieldMap = new Map<String, Map<String, Schema.DescribeFieldResult>>();
        for(String api : objApiSet){
            Map<String, Schema.DescribeFieldResult> fieldMap = new Map<String, Schema.DescribeFieldResult>();
            for(Schema.SObjectField field : Core.Schema2.getFieldList(api)){
                Schema.DescribeFieldResult f = field.getDescribe();
                fieldMap.put(f.getName(), f);
            }
            objectFieldMap.put(api, fieldMap);
        }

        // 2024.01.10 - sy.lee - 표시되는 필드가 아닌 별도의 필드로 정렬하는 경우 - 임시로 삽입
        // 2025.06.18 - sy.lee - Sort되는 필드가 없는 경우 스킵한다
        Boolean useAnotherFieldForSorting = false;
        if(String.isNotBlank(params.sortedBy) && !columnList.contains(params.sortedBy)){
            useAnotherFieldForSorting = true;
            System.debug(params.sortedBy);
            for(String fieldSort : params.sortedBy.split('\\,')){
                System.debug('fieldSort : ' + fieldSort);
                columnList.add(fieldSort.trim());
            }
        }

        for(String column : columnList){
            // 관련 오브젝트의 필드 정보
            Schema.DescribeFieldResult f = objectFieldMap.get(relatedObjApi).get(column);

            if(isRelation(column)) { // A__r.B__r.Name
                currentApi = relatedObjApi;
                for(String relation : column.substringBeforeLast('.').split('\\.')){
                    Map<String, String> relationMap = getRelationMap(currentApi);
                    currentApi = relationMap.get(relation);
                    objApiSet.add(currentApi);
                }

                // Reference의 경우, 주로 Name을 노출하므로 Name을 추가해준다
                System.debug(column);
                f = getFieldMap(currentApi).get(column.substringAfterLast('.'));

                String fieldType = String.valueOf(f.getType());
                if('REFERENCE'.equals(fieldType)){
                    String nameColumn = f.isCustom() ? (column.removeEnd('__c') + '__r.Name') : (column.removeEnd('Id') + '.Name');
                    columnMap.put(nameColumn, currentApi);
                }

            }else if(!f.referenceTo.isEmpty()){ // A__c
                String anotherRelatedObjApi = f.referenceTo.get(0).getDescribe().getName();
                objApiSet.add(anotherRelatedObjApi);

                String nameColumn = f.isCustom() ? (column.removeEnd('__c') + '__r.Name') : (column.removeEnd('Id') + '.Name');
                columnMap.put(nameColumn, anotherRelatedObjApi);
            }

            columnMap.put(column, currentApi);
            currentApi = relatedObjApi;
        }

        // 2024.01.10 - sy.lee - 표시되는 필드가 아닌 별도의 필드로 정렬하는 경우 - 다시 빼준다
        if(useAnotherFieldForSorting) columnList.remove(columnList.size()-1);

        return getDescribedObjectMap(objApiSet);
    }

    /**
     * @description 릴레이션 필드 여부 파악
     * @param column Column
     *
     * @return Boolean
     */
    private static Boolean isRelation(String column){
        return column.contains('.');
    }

    private final Map<String, Map<String, String>> objectRelationMap = new Map<String, Map<String, String>>();
    /**
     * @description Relation 정보 반환
     * @param objName Object API
     *
     * @return Map<String, String>
     */
    private Map<String, String> getRelationMap(String objName){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getRelationMap ===============================');

        if(objectRelationMap.containsKey(objName)) return objectRelationMap.get(objName);

        Map<String, String> relationMap = new Map<String, String>();
        for(Schema.DescribeFieldResult f : getFieldMap(objName).values()){
            String relationshipName = f.getRelationshipName();
            if(String.isBlank(relationshipName) || f.referenceTo.isEmpty()) continue;
            relationMap.put(relationshipName, f.referenceTo.get(0).getDescribe().getName());
        }
        return relationMap;
    }

    private final Map<String, Map<String, Schema.DescribeFieldResult>> objectFieldMap = new Map<String, Map<String, Schema.DescribeFieldResult>>();
    /**
     * @description Field API => DescribeFieldResult
     * @param objName Object API
     *
     * @return Map<String, Schema.DescribeFieldResult>
     */
    private Map<String, Schema.DescribeFieldResult> getFieldMap(String objName){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getFieldMap ===============================');
        if(objectFieldMap.containsKey(objName)) return objectFieldMap.get(objName);
        Map<String, Schema.DescribeFieldResult> fieldMap = new Map<String, Schema.DescribeFieldResult>();
        for(Schema.SObjectField field : new Util_SchemaUtil().GLOBAL_DESCRIBE.get(objName).getDescribe().fields.getMap().values()){
            Schema.DescribeFieldResult f = field.getDescribe();
            fieldMap.put(f.getName(), f);
        }
        objectFieldMap.put(objName, fieldMap);
        return fieldMap;
    }

    /**
     * @description Object 정보 반환
     * @param objectApiSet Set<Object API>
     *
     * @return Map<String, Util_RelatedListUtil.RelatedObjectCls>
     */
    private Map<String, Util_RelatedListUtil.RelatedObjectCls> getDescribedObjectMap(Set<String> objectApiSet) {
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getDescribedObjectMap ===============================');
        /*
        From the v52, Opportunity's describe get the pipe line related fields if the pipe line is active.
        So we should adjust the class api version to below than 52
         */

        // All SObject
        Map<String, Util_RelatedListUtil.RelatedObjectCls> objectMap = new Map<String, Util_RelatedListUtil.RelatedObjectCls>();
        for(String sObjectType : objectApiSet){
            Util_RelatedListUtil.RelatedObjectCls objCls = new Util_RelatedListUtil.RelatedObjectCls();

            DescribeSObjectResult describeResult = new Util_SchemaUtil().GLOBAL_DESCRIBE.get(sObjectType).getDescribe();

            objCls.name = describeResult.getName();
            objCls.label = describeResult.getLabel();
            objCls.labelPlural = describeResult.getLabelPlural();
            objCls.isCustom = describeResult.isCustom();

            for(RecordTypeInfo rt : describeResult.getRecordTypeInfos()){
                objCls.recordTypes.add(new Util_RelatedListUtil.RecordTypeCls(rt));
            }

            Map<String, Schema.SObjectField> describedFields = describeResult.fields.getMap();

            for(String fieldName : describedFields.keySet()){
                // Describe the field
                Schema.SObjectField field = describedFields.get(fieldName);

                Schema.DescribeFieldResult f = field.getDescribe();

                Util_RelatedListUtil.FieldCls fc = new Util_RelatedListUtil.FieldCls();
                fc.api = f.getName();
                fc.label = f.getLabel();
                fc.required = !f.isNillable();
                fc.fieldType = String.valueOf(f.getType());
                fc.scale = f.scale;
                fc.isHtml = f.htmlFormatted;
                fc.RelationshipName = f.getRelationshipName();
                fc.isCustom = f.isCustom();
                fc.objectApi = objCls.name;

                if('PICKLIST'.equals(fc.fieldType)){
                    fc.optionList = new List<Util_RelatedListUtil.OptionCls>();
                    for(Schema.PicklistEntry pick : field.getDescribe().getPicklistValues()){
                        Util_RelatedListUtil.OptionCls oc = new Util_RelatedListUtil.OptionCls();
                        oc.label = pick.getLabel();
                        oc.value = pick.getValue();
                        fc.optionList.add(oc);
                    }
                }
                objCls.fieldMap.put(fc.api, fc);
            }

            // Object
            objectMap.put(sObjectType, objCls);
        }
        return objectMap;
    }

    public virtual ResultCls getRelatedRecord(Util_RelatedListParameters params, SObject currentRecord, Map<String, Util_RelatedListUtil.RelatedObjectCls> relatedObjectMap){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getRelatedRecord ===============================');

        String recordId = params.recordId,
            currentObjectApi = params.currentObjectApi,
            targetObjectApi = params.targetObjectApi,
            fields = params.fields,
            condition = params.condition,
            sortedBy = params.sortedBy,
            sortedDirection = params.sortedDirection,
            limitCount = params.limitCount;

        Boolean isWithOutSharing = params.isWithOutSharing,
            isPhone = params.isPhone,
            countOnly = params.countOnly;

        Boolean needAccessCheck = params.needAccessCheck == null ? false : params.needAccessCheck;


        ResultCls rc = new ResultCls();
        rc.columns = refineColumns(fields, relatedObjectMap);

        // 동적 조건문 처리 - 향상된 방식 적용
        String refinedCondition = '';

        // 동적 변수와 연산자를 포함한 조건문 처리
        if (String.isNotBlank(condition)) {
            refinedCondition = buildQueryCondition(condition, currentRecord);
        }

        System.debug('refinedCondition : ' + refinedCondition);
        rc.fromClause = ' FROM ' + targetObjectApi + (String.isNotBlank(condition) ? ' WHERE ': '') + (String.isBlank(refinedCondition) ? '' : refinedCondition);

        // 2025.01.22 - sy.lee - Count만 필요한 경우는 실제 레코드 쿼리를 스킵한다
        if(countOnly != true){
            String query = IS_TEST ? 'SELECT Id FROM Contact' : 'SELECT '
                + rc.columns
                + rc.fromClause
                + (String.isNotBlank(sortedBy) ? (' ORDER BY ' + sortedBy + ' ' + ('asc'.equals(sortedDirection) ? ' ASC NULLS FIRST ' : ' DESC NULLS LAST')) : '')
                + (String.isBlank(limitCount) ? '' : (' LIMIT ' + limitCount));

            System.debug(query);
            // 레코드 조회
            List<SObject> recordList = isWithOutSharing ? Util_WithoutSharingUtil.getQueryWithBinds(query, new Map<String, Object>(), AccessLevel.SYSTEM_MODE) : Database.query(query);

            // todo User Access
            Map<String, Util_UserUtil.AccessCls> accessMap = new Map<String, Util_UserUtil.AccessCls>();
            if(needAccessCheck && !recordList.isEmpty()) accessMap = Core.User2.getRecordAccess(UserInfo.getUserId(), recordList);


            // 2024.01.04 - sy.lee
            // FATAL_ERROR System.UnexpectedException: Apex approval lock/unlock api preference not enabled.
            // Setup->Create-> Workflows and Approvals -> Process Automation Settings -> Enable record locking and unlocking in Apex 설정안되어 있으면 에러남
            Map<Id, Boolean> isLockMap;
            try{
                isLockMap = Approval.isLocked(recordList);
            }catch(Exception e){
                isLockMap = new Map<Id, Boolean>();
            }

            for(SObject record : recordList){
                RecordCls recordCls = new RecordCls();
                recordCls.record = record;

                Util_UserUtil.AccessCls recordAccess = accessMap.get(record.Id);
                recordCls.hasReadAccess = needAccessCheck ? recordAccess.HasReadAccess : true;
                recordCls.hasEditAccess = needAccessCheck ? recordAccess.HasEditAccess : true;
                recordCls.hasDeleteAccess = needAccessCheck ? recordAccess.HasDeleteAccess : true;
                recordCls.isLocked = isLockMap.isEmpty() ? false : isLockMap.get(record.Id);
                rc.recordList.add(recordCls);
            }

            rc.query = query;
        }

        // Big Object 처리
        if(!targetObjectApi.endsWith('__b')){
            rc.countQuery = IS_TEST ? 'SELECT count() FROM Contact' : 'SELECT count() ' + rc.fromClause;
            rc.totalRecordCount = Database.countQuery(rc.countQuery);
        }
        return rc;
    }

    /**
     * 쿼리 조건문 문자열을 파싱하여 완전한 SOQL 조건문으로 변환
     * 동적 변수와 다양한 연산자를 지원
     */
    private String buildQueryCondition(String condition, SObject currentRecord) {
        // 입력이 없으면 빈 문자열 반환
        if (String.isBlank(condition)) {
            return '';
        }

        String query_string = condition.trim();

        // 특별한 처리가 필요 없으면 원본 반환
        if (!query_string.contains(':') &&
            !query_string.contains('OR') &&
            !query_string.contains('AND') &&
            !query_string.contains('LIKE') &&
            !query_string.contains('NOT') &&
            !query_string.contains('=') &&
            !query_string.contains('<') &&
            !query_string.contains('>')){
            return query_string;
        }

        // 따옴표로 둘러싸인 문자열을 임시로 치환
        Map<String, String> quotedStringsMap = new Map<String, String>();
        Integer placeholderCounter = 0;
        String modifiedQueryString = query_string;

        // 작은따옴표로 둘러싸인 문자열 처리
        Pattern singleQuotePattern = Pattern.compile('\'([^\']*)\'');
        Matcher sqMatcher = singleQuotePattern.matcher(query_string);

        while (sqMatcher.find()) {
            String quotedString = sqMatcher.group();
            String placeholder = '__QUOTED_STRING_' + placeholderCounter++ + '__';
            quotedStringsMap.put(placeholder, quotedString);

            // 모든 일치 항목 대체 (String.replace는 모든 일치 항목을 대체함)
            modifiedQueryString = modifiedQueryString.replace(quotedString, placeholder);
        }
        query_string = modifiedQueryString;

        // 연산자 패턴 정의 (우선순위 고려)
        Pattern operatorPattern = Pattern.compile(
            '\\s+(?:NOT\\s+LIKE|LIKE|NOT\\s+IN|IN|NOT\\s+BETWEEN|BETWEEN|IS\\s+NOT\\s+NULL|IS\\s+NULL|' +
                'ISBLANK|ISNULL|ISTRUE|ISFALSE|!=|>=|<=|>|<|=|OR\\b|AND\\b|NOT\\b|' +
                'LAST_N_DAYS:|NEXT_N_DAYS:|LAST_N_WEEKS:|NEXT_N_WEEKS:|THIS_WEEK|LAST_WEEK|NEXT_WEEK|' +
                'THIS_MONTH|LAST_MONTH|NEXT_MONTH|THIS_QUARTER|LAST_QUARTER|NEXT_QUARTER|' +
                'THIS_YEAR|LAST_YEAR|NEXT_YEAR|THIS_FISCAL_QUARTER|LAST_FISCAL_QUARTER|NEXT_FISCAL_QUARTER|' +
                'THIS_FISCAL_YEAR|LAST_FISCAL_YEAR|NEXT_FISCAL_YEAR|TODAY|YESTERDAY|TOMORROW)'
        );

        // 토큰화
        List<String> tokens = new List<String>();
        Integer lastPosition = 0;
        Matcher matcher = operatorPattern.matcher(' ' + query_string + ' ');

        // 모든 연산자를 찾아 토큰화
        while (matcher.find()) {
            String beforeOperator = query_string.substring(lastPosition, matcher.start() - 1).trim();
            if (String.isNotBlank(beforeOperator)) {
                tokens.add(beforeOperator);
            }
            tokens.add(matcher.group().trim());
            lastPosition = matcher.end() - 1;
        }

        // 마지막 부분 처리
        if (lastPosition < query_string.length()) {
            String remaining = query_string.substring(lastPosition).trim();
            if (String.isNotBlank(remaining)) {
                tokens.add(remaining);
            }
        }

        // 토큰이 없으면 간단하게 처리
        if (tokens.isEmpty()) {
            // = 기호만 있는 간단한 조건 처리
            if (query_string.contains('=')) {
                List<String> parts = query_string.split('=');
                String refinedCondition = '';

                for (Integer i = 0; i < parts.size(); i++) {
                    String part = parts[i].trim();

                    // 따옴표로 둘러싸인 문자열 플레이스홀더 복원
                    for (String placeholder : quotedStringsMap.keySet()) {
                        if (part.contains(placeholder)) {
                            part = part.replace(placeholder, quotedStringsMap.get(placeholder));
                        }
                    }

                    if (part.startsWith(':')) {
                        String varName = part.substringAfter(':');
                        String value;

                        if ('recordid'.equalsIgnoreCase(varName)) {
                            value = '\'' + currentRecord.get('Id') + '\'';
                        } else if ('currentuserid'.equalsIgnoreCase(varName)) {
                            value = '\'' + UserInfo.getUserId() + '\'';
                        } else {
                            Object fieldValue = currentRecord.get(varName);
                            value = fieldValue != null ? '\'' + String.escapeSingleQuotes(String.valueOf(fieldValue)) + '\'' : 'null';
                        }

                        refinedCondition += (i > 0 ? '=' : '') + value;
                    } else {
                        refinedCondition += (i > 0 ? '=' : '') + part;
                    }
                }

                return refinedCondition;
            }

            // 원본 쿼리에 따옴표 문자열 복원
            for (String placeholder : quotedStringsMap.keySet()) {
                query_string = query_string.replace(placeholder, quotedStringsMap.get(placeholder));
            }
            return query_string;
        }

        // 토큰을 처리하여 최종 쿼리 조건 생성
        String refinedCondition = '';
        for (Integer i = 0; i < tokens.size(); i++) {
            String token = tokens[i].trim();

            // 빈 토큰 무시
            if (String.isBlank(token)) {
                continue;
            }

            // 따옴표로 둘러싸인 문자열 플레이스홀더 복원
            for (String placeholder : quotedStringsMap.keySet()) {
                if (token.contains(placeholder)) {
                    token = token.replace(placeholder, quotedStringsMap.get(placeholder));
                }
            }

            // 변수 치환 처리
            if (token.startsWith(':')) {
                String varName = token.substring(1).toLowerCase();
                String value;

                // 특별 변수 처리
                if (varName == 'recordid') {
                    value = '\'' + currentRecord.Id + '\'';
                } else if (varName == 'currentuserid') {
                    value = '\'' + UserInfo.getUserId() + '\'';
                } else {
                    // 현재 레코드에서 필드값 추출
                    Object fieldValue;

                    // 관계 필드 처리 (CustomObject__r.FieldName)
                    if (varName.contains('.')) {
                        List<String> relationParts = varName.split('\\.');
                        SObject relatedObj = currentRecord;

                        // 관계 체인 탐색
                        for (Integer j = 0; j < relationParts.size() - 1; j++) {
                            String relationName = relationParts[j];
                            relatedObj = relatedObj.getSObject(relationName);

                            if (relatedObj == null) {
                                break;
                            }
                        }

                        if (relatedObj != null) {
                            fieldValue = relatedObj.get(relationParts[relationParts.size() - 1]);
                        }
                    } else {
                        fieldValue = currentRecord.get(varName);
                    }

                    // 필드 타입에 맞는 포맷 적용
                    if (fieldValue == null) {
                        value = 'null';
                    } else if (fieldValue instanceof String || fieldValue instanceof Id) {
                        value = '\'' + String.escapeSingleQuotes(String.valueOf(fieldValue)) + '\'';
                    } else if (fieldValue instanceof Boolean) {
                        value = String.valueOf(fieldValue);
                    } else if (fieldValue instanceof Date) {
                        value = formatDate((Date)fieldValue);
                    } else if (fieldValue instanceof Datetime) {
                        value = formatDatetime((Datetime)fieldValue);
                    } else {
                        value = String.valueOf(fieldValue);
                    }
                }
                refinedCondition += value;
            }
            // 연산자 처리
            else if (isOperator(token)) {
                // 날짜 함수 형식 처리 (LAST_N_DAYS:5 형태)
                if (token.contains(':')) {
                    String[] parts = token.split(':');
                    String dateFunctionName = parts[0].trim();
                    String dateFunctionValue = parts.size() > 1 ? parts[1].trim() : '';
                    refinedCondition += ' ' + dateFunctionName + ':' + dateFunctionValue;
                }
                // 일반 연산자 처리
                else {
                    refinedCondition += ' ' + token + ' ';
                }
            }
            // 필드 또는 값 처리
            else {
                refinedCondition += token;
            }
        }

        System.debug('Final refined condition: ' + refinedCondition);
        return refinedCondition.trim();
    }

    /**
     * 주어진 토큰이 연산자인지 확인
     */
    private Boolean isOperator(String token) {
        Set<String> operators = new Set<String>{
            'OR', 'AND', 'NOT', 'LIKE', 'NOT LIKE', 'IN', 'NOT IN', 'BETWEEN', 'NOT BETWEEN',
            'IS NULL', 'IS NOT NULL', 'ISBLANK', 'ISNULL', 'ISTRUE', 'ISFALSE',
            '!=', '>=', '<=', '>', '<', '=',
            'TODAY', 'YESTERDAY', 'TOMORROW',
            'THIS_WEEK', 'LAST_WEEK', 'NEXT_WEEK',
            'THIS_MONTH', 'LAST_MONTH', 'NEXT_MONTH',
            'THIS_QUARTER', 'LAST_QUARTER', 'NEXT_QUARTER',
            'THIS_YEAR', 'LAST_YEAR', 'NEXT_YEAR',
            'THIS_FISCAL_QUARTER', 'LAST_FISCAL_QUARTER', 'NEXT_FISCAL_QUARTER',
            'THIS_FISCAL_YEAR', 'LAST_FISCAL_YEAR', 'NEXT_FISCAL_YEAR'
        };

        // LAST_N_DAYS:5 같은 형식 처리
        if (token.startsWith('LAST_N_DAYS:') || token.startsWith('NEXT_N_DAYS:') ||
            token.startsWith('LAST_N_WEEKS:') || token.startsWith('NEXT_N_WEEKS:') ||
            token.startsWith('LAST_N_MONTHS:') || token.startsWith('NEXT_N_MONTHS:') ||
            token.startsWith('LAST_N_QUARTERS:') || token.startsWith('NEXT_N_QUARTERS:') ||
            token.startsWith('LAST_N_YEARS:') || token.startsWith('NEXT_N_YEARS:') ||
            token.startsWith('LAST_N_FISCAL_QUARTERS:') || token.startsWith('NEXT_N_FISCAL_QUARTERS:') ||
            token.startsWith('LAST_N_FISCAL_YEARS:') || token.startsWith('NEXT_N_FISCAL_YEARS:')) {
            return true;
        }

        return operators.contains(token.toUpperCase());
    }

    /**
     * Date 형식 포맷
     */
    private String formatDate(Date d) {
        return d.year() + '-' +
            String.valueOf(d.month()).leftPad(2, '0') + '-' +
            String.valueOf(d.day()).leftPad(2, '0');
    }

    /**
     * Datetime 형식 포맷
     */
    private String formatDatetime(Datetime dt) {
        return dt.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
    }

    /**
     * @description 컬럼 정제
     * @param columns Columns
     * @param relatedObjectMap 관련 Object 정보
     *
     * @return String
     */
    private String refineColumns(String columns, Map<String, Util_RelatedListUtil.RelatedObjectCls> relatedObjectMap){
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.refineColumns ===============================');

        List<String> refinedColumnList = new List<String>();

        if(relatedObjectMap != null){
            for(String column : getColumnList(columns)){
                String objApi = columnMap.get(column);

                Boolean isRelation = isRelation(column);

                Util_RelatedListUtil.FieldCls fc = relatedObjectMap.get(objApi).fieldMap.get(isRelation ? column.substringAfterLast('.') : column);

                Boolean isCustom = fc.isCustom;
                String api = fc.api;
                switch on fc.fieldType {
                    when 'REFERENCE' {
                        // Look up or Master detail fields need label field for displaying label.
                        refinedColumnList.add(column.contains('.') ? column : api);
                        String nameApi = isCustom ? api.removeEnd('__c') + '__r.Name' : api.removeEnd('Id') + '.Name';
                        refinedColumnList.add(isRelation ? (isCustom ? column.removeEnd('__c') + '__r.Name' : column.removeEnd('Id') + '.Name') : nameApi);
                    }
                    when 'PICKLIST' {
                        // Pick list value should be translated
                        refinedColumnList.add('toLabel(' + (column.contains('.') ? column : api) + ')');
                    }
                    when 'CURRENCY', 'DATETIME' { // 2024.01.08 - sy.lee - DateTime에 format 적용
                        refinedColumnList.add('FORMAT(' + (column.contains('.') ? column : api) + ')');
                    }
                    when else {
                        refinedColumnList.add(column);
                    }
                }
            }
        }

        refinedColumnList.add('Id');

        // 2024.07.08 - sy.lee - Group 같은 경우 CurrencyIsoCode가 없을 수 있으므로 해당 코드 주석 처리
        /*if(Util_SchemaUtil.GLOBAL_DESCRIBE.containsKey('CurrencyType')){
            refinedColumnList.add('CurrencyIsoCode');
        }*/

        return String.join(refinedColumnList, ',');
    }

    /*public virtual ResultCls getTotalRecordCount(Util_RelatedListParameters params, SObject currentRecord){
        ResultCls rc = new ResultCls();

        String targetObjectApi = params.targetObjectApi,
                condition = params.condition;

        String refinedCondition = '';
        // 동적인 변수의 값을 담기 위한 맵
        if(condition.contains(':')){ // 동적 변수가 있을때 수행
            for(String fragment : condition.split(' ')){
                String var = fragment.trim();

                if(!var.trim().startsWith(':')){ // 동적 변수가 아닌 경우는 그냥 넘긴다
                    refinedCondition += (' ' + var);
                    continue;
                }

                // Relation 필드인 경우는? -> 수식필드를 만들어서 처리

                // String에 Id 값이 한번 들어가면 자동으로 해당 필드 타입이 Id로 잡힘
                String value = '\'' + (':recordid'.equals(var.toLowerCase()) ? currentRecord.get('Id') : String.valueOf(currentRecord.get(var.substringAfter(':')))) + '\'';
                refinedCondition += (' ' + value);
            }
        }

        // ex) FROM Quote where OpportunityId = :recordId AND OwnerId = :currentUserId
        // ex) FROM Quote where OpportunityId = :recordId AND ExpirationDate = :TODAY - 이건 일단 필드로 해결하자

        rc.fromClause = ' FROM ' + targetObjectApi + ' WHERE ' + (String.isBlank(refinedCondition) ? '' : refinedCondition);
        if(!targetObjectApi.endsWith('__b')){
            rc.countQuery = 'SELECT count() ' + rc.fromClause;
            rc.totalRecordCount = IS_TEST ? 1 : Database.countQuery(rc.countQuery);
        }
        return rc;
    }*/

    public virtual Util_RelatedListUtil.CurrentObjectCls getCurrentObject(Util_RelatedListParameters params) {
        System.debug(LoggingLevel.INFO, '==================== Util_RelatedListUtil.getCurrentObject ===============================');

        String recordId = params.recordId,
            currentObjectApi = params.currentObjectApi,
            currentObjectFields = params.currentObjectFields,
            condition = params.condition;
        Boolean applyApprovalLock = params.applyApprovalLock;


        DescribeSObjectResult currentObject = Core.Schema2.getObjectResult(currentObjectApi);
        Util_RelatedListUtil.CurrentObjectCls cc = new Util_RelatedListUtil.CurrentObjectCls();
        cc.name = currentObject.getName();
        cc.label = currentObject.getLabel();
        cc.labelPlural = currentObject.getLabelPlural();

        Set<String> fieldSet = new Set<String>();
        // todo - 어케할까여
        //fieldSet.addAll(new List<String>{'Id', 'Name', 'Owner.Profile.Name', 'Owner.UserRole.Name'});
        fieldSet.addAll(new List<String>{'Id', 'Name'});

        // 추가 쿼리 필요한 부모 필드
        if(String.isNotBlank(currentObjectFields)) fieldSet.addAll(currentObjectFields.split(','));

        // 멀티 커런시가 활성화 된 경우
        if(Core.Schema2.GLOBAL_DESCRIBE.containsKey('CurrencyType')) fieldSet.add('CurrencyIsoCode');

        if(String.isNotBlank(condition) && condition.contains(':')){ // 동적 변수가 있을때 수행
            for(String fragment : condition.split(' ')){
                String var = fragment.trim();

                if(':recordid'.equals(var.toLowerCase())) continue; // 레코드 아이디도 그냥 넘김
                if(!var.startsWith(':')) continue; // 동적 변수가 아닌 경우는 그냥 넘긴다

                fieldSet.add(var.substringAfter(':'));
            }
        }

        System.debug('recordId : ' + recordId);
        System.debug('SELECT ' + String.join(fieldSet, ',') + ' FROM ' + String.escapeSingleQuotes(currentObjectApi) + ' WHERE Id = :recordId');

        cc.record = IS_TEST ? [SELECT Id FROM User LIMIT 1] : Database.query('SELECT ' + String.join(fieldSet, ',') + ' FROM ' + String.escapeSingleQuotes(currentObjectApi) + ' WHERE Id = :recordId');

        // 2024.01.04 - sy.lee
        // FATAL_ERROR System.UnexpectedException: Apex approval lock/unlock api preference not enabled.
        // Setup->Create-> Workflows and Approvals -> Process Automation Settings -> Enable record locking and unlocking in Apex 설정안되어 있으면 에러남
        try{
            cc.isLocked = applyApprovalLock ? Approval.isLocked(recordId) : false;
        }catch(Exception e){
            cc.isLocked = false;
        }
        return cc;
    }

    // =================================================================================================================
    // Sharing 구분을 위한 Inner Class
    public with sharing class WithSharing extends Util_RelatedListUtil{}
    public without sharing class WithoutSharing extends Util_RelatedListUtil{}

    // =================================================================================================================
    // 정보를 넣기위한 Inner Class

    /**
     * @description 현재 Object 정보를 담는 Innner Class
     */
    public class CurrentObjectCls {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String labelPlural;
        @AuraEnabled public String relationshipName;
        @AuraEnabled public SObject record;
        @AuraEnabled public Boolean isLocked;
    }

    /**
     * @description 관련 오브젝트 정보를 담는 Inner Class
     */
    public class RelatedObjectCls {
        @AuraEnabled public String name;
        @AuraEnabled public String label;
        @AuraEnabled public String labelPlural;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public List<RecordTypeCls> recordTypes;
        @AuraEnabled public Map<String, FieldCls> fieldMap;

        public RelatedObjectCls(){
            this.recordTypes = new List<RecordTypeCls>();
            this.fieldMap = new Map<String, FieldCls>();
        }
    }

    /**
     * @description Record Type 정보를 담는 Inner Class
     */
    public class RecordTypeCls {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Boolean isMaster;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Boolean isAvailable;

        public RecordTypeCls(RecordTypeInfo rt){
            this.id = rt.getRecordTypeId();
            this.label = rt.getName();
            this.value = rt.getDeveloperName();
            this.isMaster = rt.isMaster();
            this.isActive = rt.isActive();
            this.isAvailable = rt.isAvailable();
        }
    }

    /**
     * @description Field 정보를 담는 Inner Class
     */
    public class FieldCls {
        @AuraEnabled public String label;
        @AuraEnabled public String api;
        @AuraEnabled public String fieldType;
        @AuraEnabled public Boolean required;
        @AuraEnabled public Integer scale;
        @AuraEnabled public List<OptionCls> optionList;
        @AuraEnabled public String RelationshipName;
        @AuraEnabled public Boolean isCustom;
        @AuraEnabled public Boolean isHtml;
        @AuraEnabled public String objectApi;
    }

    /**
     * @description 선택목록 옵션을 담는 Inner Class
     */
    public class OptionCls {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
    }

    /**
     * @description 결과 정보를 담는 Inner Class
     */
    public class ResultCls {
        //@AuraEnabled public Boolean isCommunity = String.isNotBlank(Site.getSiteId());
        //@AuraEnabled public String orgDomain = (isCommunity ? [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :Site.getSiteId() LIMIT 1].SecureUrl : Url.getOrgDomainUrl().toExternalForm()) + '/';
        @AuraEnabled public List<RecordCls> recordList;
        @AuraEnabled public Integer totalRecordCount = 0;
        //@AuraEnabled public Util_RelatedListUtil.CurrentObjectCls currentObject;
        //@AuraEnabled public TargetObjectCls parent;
        @AuraEnabled public String query;      // Refresh를 위해 Query를 담는다
        @AuraEnabled public String countQuery; // Refresh를 위해 Query를 담는다
        @AuraEnabled public String columns;
        @AuraEnabled public String fromClause;
        //@AuraEnabled public Map<String, UserRecordAccess> accessMap;

        public ResultCls(){
            this.recordList = new List<RecordCls>();
        }
    }

    /**
     * @description Record 정보를 담는 Inner Class
     */
    public class RecordCls {
        @AuraEnabled public SObject record;
        @AuraEnabled public Boolean hasReadAccess;
        @AuraEnabled public Boolean hasEditAccess;
        @AuraEnabled public Boolean hasDeleteAccess;
        @AuraEnabled public Boolean isLocked;
    }
}