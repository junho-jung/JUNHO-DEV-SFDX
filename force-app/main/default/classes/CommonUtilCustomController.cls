/**
* @Author            : jh.jung
* @Description 		 : 공통Util Custom 함수 Controller
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
public without sharing class CommonUtilCustomController {

    private static final String HEROKU_PDF_IF_ID = 'HEROKU_SFDC_PDF';

    public static final Map<String, String> SEGMENT1_MAP = CommonUtilController.getPickListMap('Product2', 'Segment1__c');
    public static final Map<String, String> CAB_MARK_MAP = CommonUtilController.getPickListMap('Product2', 'CabMark__c');
    public static final Map<String, String> INTARDER_MAP = CommonUtilController.getPickListMap('Product2', 'Intarder__c');
    public static final Map<String, String> WHEEL_BASE_MAP = CommonUtilController.getPickListMap('Product2', 'WheelBase__c');
    public static final Map<String, String> TRIM_LEVEL_MAP = CommonUtilController.getPickListMap('Product2', 'TrimLevel__c');
    public static final Map<String, String> EMISSION_LEVEL_MAP = CommonUtilController.getPickListMap('Product2', 'EmissionLevel__c');
    public static final Map<String, String> SPEC_PREIFX_MAP = CommonUtilController.getPickListMap('VehicleStock__c', 'SpecPrefix__c');

    /**
     * @param ifId      Interface Id
     * @param items     Input DTO
     * @param logId     Update대상 logId
     * @description     SAP를 위한 parse String
     * @return          String Value
     */
    public static String parseStringSAP(String ifId, Object items, String logId) {
        JSONGenerator generator = JSON.createGenerator(true);

        List<Map<String, Object>> infos = new List<Map<String, Object>>();
        List<Object> rawItems = (List<Object>) items;
        for (Object item : rawItems) {
            Map<String, Object> itemMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(item));
            Map<String, Object> cleanedMap = new Map<String, Object>();

            for (String key : itemMap.keySet()) {
                // null값 필드제외
                if (itemMap.get(key) != null) cleanedMap.put(key, itemMap.get(key));
            }
            infos.add(cleanedMap);
        }
        String id = ifId.replace('HEROKU_', '').replace('(Async)', '');

        generator.writeStartObject();
        generator.writeStringField('ID', id);
        generator.writeObjectField('ITEMS', infos);
        if(logId != null) generator.writeObjectField('LOG_ID', logId);

        generator.writeEndObject();

        return generator.getAsString();
    }

    /**
     * @param segment       ex, String [Tipper, Tractor, Cargo, Bus, Cargo/Distribution, Tractor/Long-haul, Tipper/Traction, etc...]
     * @param specShortRaw  ex, String [TGL 10.190 4x2 BL CH, etc...]
     * @param cabMark       ex, String [M, L, LX, etc...]
     * @param intarder      ex, String [No Intarder, Intarder, Pretarder, etc...]
     * @param wheelBase     ex, String [2900, 3205, 3100, 3600, etc...]
     * @param trimLevel     ex, String [Premium, Economic, Standard, El, etc...]
     * @param emissionLevel ex, String [Euro5, Euro6, Euro6C, Euro6D, Euro6E, Euro3, etc...]
     * @description         데이터 Raw값을 받은 후 ERP에 대응되는 코드 생성
     * @return              String Value(Length = 14)
     */
    public static String parseCarCode(String segment, String specShortRaw, String cabMark, String intarder, String wheelBase, String trimLevel, String emissionLevel) {
        String returnCode = '';
        String stringRaw = specShortRaw;

        List<String> delChars = new List<String>{'.', '_', '-', '/', '='};
        for(String delChar : delChars) {
            stringRaw = stringRaw.replace(delChar, ' ');
        }
        List<String> strList = stringRaw.split(' ');

        returnCode += CommonUtilController.sliceUBarBefore(SEGMENT1_MAP.get(segment));
        returnCode += CommonUtilController.sliceUBarBefore(SPEC_PREIFX_MAP.get(strList[0]));
        returnCode += ('0' + strList[1]).right(2) + ('00' + strList[2]).right(3);
        returnCode += strList[3].toUpperCase().remove('X').right(2);
        returnCode += CommonUtilController.sliceUBarBefore(CAB_MARK_MAP.get(cabMark));
        returnCode += CommonUtilController.sliceUBarBefore(INTARDER_MAP.get(intarder));
        returnCode += CommonUtilController.sliceUBarBefore(WHEEL_BASE_MAP.get(wheelBase));
        returnCode += CommonUtilController.sliceUBarBefore(TRIM_LEVEL_MAP.get(trimLevel));
        returnCode += CommonUtilController.sliceUBarBefore(EMISSION_LEVEL_MAP.get(emissionLevel));

        System.debug(returnCode);
        return returnCode.length() == 14 ? returnCode : null;
    }

    /**
     * @param vinList       VIN(차대번호) List
     * @description         차대번호에 따른 ModelYear Return, 박지현 대리님 제공
     * @return              Map<String, String> Value
     */
    public static Map<String, String> getYearByVIN(List<String> vinList) {
        Map<String, String> returnMap = new Map<String, String>();

        for(String vin : vinList) {
            String code = vin.substring(9, 10);
            String year = null;
            switch on code {
                when 'A' { year = '2010'; }
                when 'B' { year = '2011'; }
                when 'C' { year = '2012'; }
                when 'D' { year = '2013'; }
                when 'E' { year = '2014'; }
                when 'F' { year = '2015'; }
                when 'G' { year = '2016'; }
                when 'H' { year = '2017'; }
                when 'J' { year = '2018'; }
                when 'K' { year = '2019'; }
                when 'L' { year = '2020'; }
                when 'M' { year = '2021'; }
                when 'N' { year = '2022'; }
                when 'P' { year = '2023'; }
                when 'R' { year = '2024'; }
                when 'S' { year = '2025'; }
                when 'T' { year = '2026'; }
                when 'V' { year = '2027'; }
                when 'W' { year = '2028'; }
                when 'X' { year = '2029'; }
                when 'Y' { year = '2030'; }
                when '1' { year = '2031'; }
                when '2' { year = '2032'; }
                when '3' { year = '2033'; }
                when '4' { year = '2034'; }
                when '5' { year = '2035'; }
                when '6' { year = '2036'; }
                when '7' { year = '2037'; }
                when '8' { year = '2038'; }
                when '9' { year = '2039'; }
            }

            returnMap.put(vin, year);
        }

        return returnMap;
    }

    /**
     * @param spec      ex, TGL 10.220 4x2 BL CH
     * @return          Map<String, String> value ('modelType', 'axleConfiguration', 'suspension', 'weightCapacity', 'horsePower')
     * @description     ex
     *                  1. key : modelType, value : TGL
     *                  2. key : weightCapacity, value : 10
     *                  3. key : horsePower, value : 220
     *                  4. key : axlConfiguration, value : 4x2
     *                  5. key : suspension, value : BL
     */
    public static Map<String, String> getSpecMap(String spec) {
        Map<String, String> specMap = new Map<String, String>();

        List<String> specList = spec.split(' ');
        List<String> grossWeightHorsePower = specList.get(1).split('\\.');

        specMap.put('modelType', specList.get(0));
        specMap.put('axleConfiguration', specList.get(2));
        specMap.put('suspension', specList.get(3));

        if(grossWeightHorsePower.size() == 2) {
            specMap.put('weightCapacity', grossWeightHorsePower.get(0));
            specMap.put('horsePower', grossWeightHorsePower.get(1));
        }

        return specMap;
    }

    public static String parseIFId(String prefix) {
        Datetime now = System.now();
        String retStr = prefix;
        retStr += now.format('yyyyMMddHHmmss');

        String mSec = String.valueOf(now.millisecond());
        String zero = '';
        for(Integer i = 0; i < 3-mSec.length(); i++) {
            zero += '0';
        }
        retStr += zero + mSec;

        return retStr;
    }

    /**
     * @author                  송찬영
     * @param masterCodeList    ConfigMaster의 코드값 List
     * @description             단일 Code값을 기준으로 ConfigDetail들의 값 Return
     * @return                  List<ConfigDetail__c> value
     */
//    public static List<ConfigDetail__c> getConfigDetailList(List<String> masterCodeList) {
//        return [
//            SELECT Id, IsDeleted, Name,
//                Attribute1__c, Attribute2__c, Attribute3__c, Attribute4__c, Attribute5__c, Attribute6__c, Attribute7__c, Attribute8__c, Attribute9__c, Attribute10__c,
//                Attribute11__c, Attribute12__c, Attribute13__c, Attribute14__c, Attribute15__c, Attribute16__c, Attribute17__c, Attribute18__c, Attribute19__c, Attribute20__c,
//                ConfigMaster__c, ConfigMaster__r.Name, ConfigMaster__r.Value__c,
//                ConfigMaster__r.Parent__c, fm_UpperCode__c, fm_UpperValue__c
//            FROM ConfigDetail__c
//            WHERE ConfigMaster__r.Name IN :masterCodeList
//        ];
//    }

    /**
     * @author                  송찬영
     * @param upperCode         ConfigMaster의 상위 코드값
     * @description             단일 상위 Code값을 기준으로 하위 ConfigMaster의 Detail들의 값 Return
     * @return                  List<ConfigDetail__c> value
     */
//    public static List<ConfigDetail__c> getConfigDetailLow(String upperCode) {
//        return [
//            SELECT Id, IsDeleted, Name,
//                Attribute1__c, Attribute2__c, Attribute3__c, Attribute4__c, Attribute5__c, Attribute6__c, Attribute7__c, Attribute8__c, Attribute9__c, Attribute10__c,
//                Attribute11__c, Attribute12__c, Attribute13__c, Attribute14__c, Attribute15__c, Attribute16__c, Attribute17__c, Attribute18__c, Attribute19__c, Attribute20__c,
//                ConfigMaster__c, ConfigMaster__r.Name, ConfigMaster__r.Value__c,
//                ConfigMaster__r.Parent__c, fm_UpperCode__c, fm_UpperValue__c
//            FROM ConfigDetail__c
//            WHERE ConfigMaster__r.Name = :upperCode
//        ];
//    }

    // 모두싸인 코드값
    private final static String SIGN_CODE = 'MAN9000';
//    public static List<Map<String, Object>> getConfigMapList(String templateTitle) {
//        List<Map<String, Object>> configMapList = new List<Map<String, Object>>();
//
//        String templateCode = null;
//        Map<String, ConfigDetail__c> signMap = new Map<String, ConfigDetail__c>();
//        for(ConfigDetail__c detail : CommonUtilCustomController.getConfigDetailLow(SIGN_CODE)) {
//            // Template Title에 해당하는 Code Get
//            if(detail.Attribute1__c.equals(templateTitle)) templateCode = detail.Name;
//
//            signMap.put(detail.Name, detail);
//        }
//
//        Map<String, List<ConfigDetail__c>> labelListMap = new Map<String, List<ConfigDetail__c>>();
//        for(ConfigDetail__c detail : CommonUtilCustomController.getConfigDetailLow(templateCode)) {
//            String key = detail.ConfigMaster__r.Name;
//            List<ConfigDetail__c> codeList = labelListMap.containsKey(key) ? labelListMap.get(key) : new List<ConfigDetail__c>();
//
//            // Template Title에 해당하는 Label List
//            codeList.add(detail);
//            labelListMap.put(key, codeList);
//        }
//
//        // 전체 Template중. Template Title에 해당하는 데이터만 Get
//        for(ConfigDetail__c sign : signMap.values()) {
//            List<ConfigDetail__c> labelList = labelListMap.containsKey(sign.Name) ? labelListMap.get(sign.Name) : new List<ConfigDetail__c>();
//
//            // 파라미터로 받은 Code값의 Detail List
//            for(ConfigDetail__c label : labelList) {
//                Map<String, Object> configMap = new Map<String, Object>();
//                configMap.put('dataLabel', label.Name);
//                configMap.put('value', label.Attribute1__c);
//
//                configMapList.add(configMap);
//            }
//        }
//
//        return configMapList;
//    }

    // ManCode 코드값
    private final static String MAN_CODE = 'MAN5000';
//    public static Map<String, Map<String, ConfigDetail__c>> getCodeMap(String manCode) {
//        Map<String, Map<String, ConfigDetail__c>> returnMap = new Map<String, Map<String, ConfigDetail__c>>();
//
//        Map<String, String> detailMap = new Map<String, String>();
//        for(ConfigDetail__c detail : CommonUtilCustomController.getConfigDetailLow(manCode)) {
//            detailMap.put(detail.Name, detail.Attribute1__c);
//        }
//
//        List<String> codeList = new List<String>(detailMap.keySet());
//        for(ConfigDetail__c detail : CommonUtilCustomController.getConfigDetailList(codeList)) {
//            String key = detail.ConfigMaster__r.Name;
//
//            Map<String, ConfigDetail__c> configMap = returnMap.containsKey(key) ? returnMap.get(key) : new Map<String, ConfigDetail__c>();
//
//            configMap.put(detail.Name, detail);
//            returnMap.put(key, configMap);
//        }
//
//        return returnMap;
//    }

    /**
     * @author th.kim
     * @description Log 데이터 생성
     * @param logWrapper Log 데이터
     */
//    public static void setLog(IF_DTO.LogWrapper logWrapper) {
//        final Integer MAX_LENGTH = 130000;
//
//        IF_Log__c objLog = new IF_Log__c();
//        objLog.IF_Master__c = logWrapper.ifId;
//        objLog.Status__c = logWrapper.status;
//        objLog.RequestTime__c = logWrapper.requestTime;
//        objLog.RequestBody__c = logWrapper.requestBody != null ? logWrapper.requestBody.abbreviate(MAX_LENGTH) : null;
//        objLog.ResponseTime__c = logWrapper.responseTime;
//        objLog.ResponseBody__c = logWrapper.responseBody != null ? logWrapper.responseBody.abbreviate(MAX_LENGTH) : null;
//        objLog.ErrorCode__c = logWrapper.errorCode;
//        objLog.LogType__c = String.valueOf(logWrapper.logType);
//
//        insert objLog;
//    }

    /**
     * @author payo03@solomontech.net
     * @description LogList 데이터 생성
     * @param logWrapperList LogList 데이터
     */
//    public static void setLogList(List<IF_DTO.LogWrapper> logWrapperList) {
//        final Integer MAX_LENGTH = 130000;
//
//        List<IF_Log__c> logList = new List<IF_Log__c>();
//        for(IF_DTO.LogWrapper logWrapper : logWrapperList) {
//            IF_Log__c objLog = new IF_Log__c();
//
//            objLog.IF_Master__c = logWrapper.ifId;
//            objLog.Status__c = logWrapper.status;
//            objLog.RequestTime__c = logWrapper.requestTime;
//            objLog.RequestBody__c = logWrapper.requestBody != null ? logWrapper.requestBody.abbreviate(MAX_LENGTH) : null;
//            objLog.ResponseTime__c = logWrapper.responseTime;
//            objLog.ResponseBody__c = logWrapper.responseBody != null ? logWrapper.responseBody.abbreviate(MAX_LENGTH) : null;
//            objLog.ErrorCode__c = logWrapper.errorCode;
//            objLog.LogType__c = String.valueOf(logWrapper.logType);
//
//            logList.add(objLog);
//        }
//        insert logList;
//    }

    /**
     * @author San.Kang
     * @description 공통 승인프로세스 실행
     * @param InfoMap => userid, recordid, comment, approvalProcess가 들어있음
     * @return String Value
     */
    @AuraEnabled
    public static String ContractAmendmentApprovalProcess(Map<String,String> InfoMap) {
        try{
            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setComments(InfoMap.get('comment'));
            req.setObjectId(InfoMap.get('recordId'));
            req.setSubmitterId(InfoMap.get('userId'));
            // Submit the record to the existing process named PTO_Reqwuest_Process
            req.setProcessDefinitionNameOrId(InfoMap.get('approvalProcess'));
            // Submit the approval request for the account
            Approval.ProcessResult result = Approval.process(req);
            System.debug(result);
            return '승인요청이 완료되었습니다.';
        }catch (Exception e){
            System.debug('e =>'+e.getMessage());
            return 'error';
        }
    }
    /**
     * @author Junho.Jung
     * @description 다중 승인프로세스
     * @param InfoMap => userid, recordid, comment, approvalProcess가 들어있음
     * @return String Value
     */
    @AuraEnabled
    public static Map<String, Object> approvalProcessList(List<Map<String,String>> infoMapList) {

        System.debug('approvalProcessList input ::: ' + infoMapList);
        Map<String, Approval.ProcessResult> returnMap = new Map<String, Approval.ProcessResult>();
        try{
            List<Approval.ProcessSubmitRequest> approvalReqList = new List<Approval.ProcessSubmitRequest>();
            for(Map<String,String> infoMap : infoMapList) {
                Approval.ProcessSubmitRequest approvalReq = new Approval.ProcessSubmitRequest();

                approvalReq.setComments(infoMap.get('comment'));
                approvalReq.setObjectId(infoMap.get('recordId'));
                approvalReq.setSubmitterId(infoMap.get('userId'));
                approvalReq.setProcessDefinitionNameOrId(infoMap.get('approvalProcess'));
                approvalReqList.add(approvalReq);
            }
            List<Approval.ProcessResult> result = Approval.process(approvalReqList, false);
            System.debug(result);

            for(Integer i=0; i<infoMapList.size(); i++) {
                returnMap.put(infoMapList.get(i).get('recordId'), result.get(i));
            }

        }catch (Exception e){
            System.debug('e =>'+e.getMessage());
        }

        System.debug('approvalProcessList return ::: ' + returnMap);
        return returnMap;
    }

    /**
     * @param recordId      Id 데이터
     * @param sendType      Task의 생성 Type
     * @param subject       Task의 Title
     * @description         InterfaceKakao, InterfaceModusign 호출한 뒤 Task Log
     * @return              Task
     */
    public static Task createTask(String recordId, String sendType, String subject) {
        String objectType = Id.valueOf(recordId).getSobjectType().getDescribe().getName();
        Schema.FieldSet fieldSet = Schema.getGlobalDescribe().get(objectType).getDescribe().fieldSets.getMap().get('TaskFieldSet'); // 신규 ObjectType추가시 TaskFieldSet 만드시오

        // Activity탭은 Opportunity만 사용. 정상일 그룹장님 요청
        String opptyObjName = 'Opportunity';
        String accountObjName = 'Account';
        Set<String> fieldList = new Set<String>();
        for (Schema.FieldSetMember field : fieldSet.getFields()) {
            String fieldName = field.fieldPath;

            fieldList.add(fieldName);

            if(fieldName.contains('Opportunity')) opptyObjName = fieldName;
            if(fieldName.contains('Account')) accountObjName = fieldName;
        }
        opptyObjName = opptyObjName.substringBefore('.');
        accountObjName = accountObjName.substringBefore('.');

        String query = CommonUtilController.buildQuery(
            String.join(fieldList, ','),
            objectType,
            CommonUtilController.buildWhereConditions(new Map<String, Object>{ 'Id' => recordId })
        );
        System.debug(query);
        SObject sObj = Database.query(query);

        SObject accountObj = (sObj instanceof Account)
            ? sObj
            : sObj.getSObject(accountObjName);
        SObject opptyObj = (sObj instanceof Opportunity)
            ? sObj
            : sObj.getSObject(opptyObjName);
        String formatDate = CommonUtilController.formatDate(Datetime.now(), 'C');
        String prefixTitle;
        switch on sendType.toUpperCase() {
            when 'MODUSIGN' { prefixTitle = '[모두싸인] '; }
            when 'KAKAO' { prefixTitle = '[카톡] '; }
        }
        // ex, [카톡] 고객정보동의서_250114
        String title = prefixTitle + subject + '_' + formatDate.substring(2, formatDate.length());

        Task task = new Task();
        task.WhatId = String.valueOf(opptyObj.get('Id'));
        task.Subject = title;
        task.Description = String.valueOf(sObj.get('Name'));
        task.Status = 'Completed';
        task.Priority = 'Normal';
        task.WhoId = String.valueOf(accountObj.get('PersonContactId'));
        task.OwnerId = UserInfo.getUserId();

        return task;
    }

//    public static Integer getPDFPageNumber(String file) {
//        IF_Util ifUtil = new IF_Util(HEROKU_PDF_IF_ID);
//        HttpResponse response = ifUtil.webCallout(file);
//
//        if (HttpCallOutConsts.SUCCESS_CODES.contains(response.getStatusCode())) {
//            String body = response.getBody();
//            if(Test.isRunningTest()) body = '1';
//
//            return Integer.valueOf(body);
//        } else {
//            return 0;
//        }
//    }

//    public static VirtualAccount__c createVirtualAccount(Map<String, Object> paramMap) {
//        VirtualAccount__c va = new VirtualAccount__c();
//
//        Opportunity oppty = (Opportunity) paramMap.get('opportunity');
//        String vamId = String.valueOf(paramMap.get('virtualAccountMasterId'));
//        Integer depositAmount = Integer.valueOf(paramMap.get('depositAmount'));
//        Date validDate = Date.valueOf(paramMap.get('validDate'));
//
//        va.Name = oppty.Account.Name + '_' + System.today();
//        va.Account__c = oppty.AccountId;
//        va.Opportunity__c = oppty.Id;
//        va.VirtualAccountMaster__c = vamId;
//        va.AssignedDate__c = System.today();
//        va.ExpireDate__c = validDate;
//        va.Payment__c = depositAmount;
//        va.IsValid__c = true;
//
//        return va;
//    }

    /**
     * @param record        필드의 Lookup SObject
     * @param field         SObject 필드
     * @description         SObject의 데이터 필드중 Lookup필드 존재할경우. 동적으로 SObject를 사용하기 위한 재귀함수 호출
     * @return              Object Value
     */
    public static Object fetchValueRecur(SObject record, String field) {
        String modifyField = modifyField(field);

        // 필드 분리작업 Start
        if (modifyField.contains('.')) {
            String relatedObject = modifyField.substringBefore('.');
            String relatedField = modifyField.substringAfter('.');

            // 필드 Lookup인경우 재귀호출
            SObject relatedRecord = record.getSObject(relatedObject);
            if(relatedRecord == null) return '';    // 03-28 송찬영. RelatedRecord 미존재시 return

            return fetchValueRecur(relatedRecord, relatedField);
        } else {
            // 단일 필드 처리
            return record.get(modifyField) != null ? record.get(modifyField) : '';
        }
    }

    // DataLabel Copy 처리
    // ex, ModuSign Template의 DataLabel명 : Copy_fm_Segment1__c2 / _Copy_Quotes.Name2
    public static String modifyField(String field) {
        if(field.toUpperCase().startsWith('COPY')) field = field.substring(5, field.length() - 1);

        return field;
    }

    /**
     * @param baseDays          기준일 범위
     * @return Map<Date, Date>  Key : 기준일. Value : 영업일 Return
     */
//    public static Map<Date, Date> availableDateMap(Integer baseDays) {
//        Map<Date, Date> availableDateMap = new Map<Date, Date>();
//
//        Set<Date> holidaySet = new Set<Date>();
//        for(CustomCalendar__c obj : [
//            SELECT Id, Date__c
//            FROM CustomCalendar__c
//            WHERE Date__c > TODAY
//            AND Date__c <= :Date.today().addMonths(1).addDays(baseDays)     // 동적으로 필요하나... 우선은 1달 + baseDay
//            AND IsHoliday__c = TRUE
//        ]) {
//            holidaySet.add(obj.Date__c);
//        }
//
//        Date baseDate = Date.today();
//        for (Integer day = 1; day <= baseDays; day++) {
//            Integer extraDays = 0;
//            Date keyDate = baseDate.addDays(day);
//
//            // 반복문 돌리면서... 휴일이 포함된경우 추가
//            for (Integer num = 1; num <= day + extraDays; num++) {
//                Date currentDate = baseDate.addDays(num);
//
//                if (holidaySet.contains(currentDate)) {
//                    extraDays++;
//                }
//            }
//            availableDateMap.put(keyDate, keyDate.addDays(extraDays));
//        }
//
//        return availableDateMap;
//    }

    /**
     * @param info      AvisOrderInfo
     * @description     필드목록 [fm_SpoilerCode__c, fm_SpoilerText__c]
     * @return          String Value
     */
//    public static String getSpoilerKey(AvisOrderInfo__c info) {
//        String code = info.fm_SpoilerText__c;
//        if (info.fm_SpoilerCode__c != null) code = info.fm_SpoilerCode__c;
//
//        return code;
//    }

    /**
     * @author chaebeom.do@solomontech.net
     * @param recordId      해제할 레코드 Id
     * @description         패러미터로 받은 레코드 잠금 해제
     */
    @future
    public static void unlockRecordAsync(Id recordId) {
        try {
            Approval.UnlockResult[] results = Approval.unlock(new Id[] {recordId});
            for (Approval.UnlockResult result : results) {
                if (result.isSuccess()) {
                    System.debug('Record unlocked: ' + result.getId());
                } else {
                    System.debug('Failed to unlock record: ' + result.getErrors()[0].getMessage());
                }
            }
        } catch (Exception e) {
            System.debug('Exception while unlocking: ' + e.getMessage());
        }
    }
}