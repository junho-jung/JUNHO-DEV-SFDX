/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-06      jh.jung           Created
  1.1      2026-01-27      jh.jung           Refactoring
*/

/**
 * @description PMS(Project Management System) 자원 관리 컨트롤러
 * 프로젝트/팀/멤버별 공수(Monthly Estimation) 현황 조회 및 저장을 담당합니다.
 */
public with sharing class PMS_ResourceManagementController {

    /**
     * @description LWC 그리드 및 데이터 처리를 위한 Wrapper 클래스
     */
    public class AllocationWrapper {
        @AuraEnabled public String  Id;                 // DB ID 또는 가상 생성 ID
        @AuraEnabled public String  CompositeKey;       // Upsert 기준 키 (PMKey_YYYYMM)
        @AuraEnabled public String  ProjectMemberId;    // ProjectMember__c ID
        @AuraEnabled public String  MemberId;           // Employee__c ID
        @AuraEnabled public String  MemberName;
        @AuraEnabled public String  TeamId;             // 부서 ID
        @AuraEnabled public String  TeamName;
        @AuraEnabled public String  ProjectId;          // Opportunity ID
        @AuraEnabled public String  ProjectName;
        @AuraEnabled public String  Role;               // 투입 역할
        @AuraEnabled public String  JobDesc;            // 직급(직무) 라벨
        @AuraEnabled public String  Grade;              // 등급
        @AuraEnabled public Integer Year;
        @AuraEnabled public Integer Month;
        @AuraEnabled public Decimal ContractMM = 0.0;   // 계획 공수
        @AuraEnabled public Decimal ActualMM = 0.0;     // 실적 공수
        @AuraEnabled public Decimal WeightedActualMM = 0.0;
        @AuraEnabled public Decimal WeightedContractMM = 0.0;
        @AuraEnabled public Boolean IsPlaceholder;

        public AllocationWrapper() {}

        /** 1. DB에 실제 공수 데이터(MonthlyEstimation__c)가 있는 경우 */
        public AllocationWrapper(MonthlyEstimation__c me) {
            this.Id = me.Id;
            this.CompositeKey = me.AllocationExternalKey__c;
            this.ProjectMemberId = me.ProjectMember__c;
            this.Year = Integer.valueOf(me.Year__c);
            this.Month = Integer.valueOf(me.Month__c);
            this.ContractMM = me.ContractMM__c ?? 0.0;
            this.ActualMM = me.ActualMM__c ?? 0.0;
            this.WeightedActualMM = me.Fm_WeightedActualMM__c ?? 0.0;
            this.WeightedContractMM = me.Fm_WeightedContractMM__c ?? 0.0;

            if (me.ProjectMember__r != null) {
                ProjectMember__c pm = me.ProjectMember__r;
                this.Role = pm.Role__c;
                this.Grade = pm.Grade__c;
                setMemberInfo(pm.Employee__r);
                setProjectInfo(pm.Opportunity__c, pm.Opportunity__r?.Name);
            }
        }

        /** 2. 멤버는 배정되었으나 해당 월 공수가 없는 경우 (Virtual) */
        public AllocationWrapper(ProjectMember__c pm, Integer year, Integer month) {
            this.ProjectMemberId = pm.Id;
            this.Year = year;
            this.Month = month;
            this.Role = pm.Role__c;
            this.Grade = pm.Grade__c;
            String strMonth = String.valueOf(month).leftPad(2, '0');
            this.CompositeKey = pm.ProjectMemberExternalKey__c + '_' + year + strMonth;
            this.Id = 'virtual_' + this.CompositeKey;
            setMemberInfo(pm.Employee__r);
            setProjectInfo(pm.Opportunity__c, pm.Opportunity__r?.Name);
        }

        /** 3. 프로젝트만 있고 멤버는 없는 행 (Project View) */
        public AllocationWrapper(Opportunity opp, Integer year, Integer month) {
            this.Year = year;
            this.Month = month;
            String strMonth = String.valueOf(month).leftPad(2, '0');
            this.CompositeKey = 'NONE_' + year + strMonth;
            this.Id = 'ignore_' + this.CompositeKey;
            setProjectInfo(opp.Id, opp.Name);
            setMemberInfo(null);
        }

        /** 4. 프로젝트 할당이 아예 없는 직원 행 (Team View) */
        public AllocationWrapper(Employee__c emp, Integer year, Integer month) {
            this.Year = year;
            this.Month = month;
            String strMonth = String.valueOf(month).leftPad(2, '0');
            this.CompositeKey = 'NONE_' + year + strMonth;
            this.Id = 'ignore_' + this.CompositeKey;
            setMemberInfo(emp);
            setProjectInfo('NONE', '(미할당)');
        }

        private void setMemberInfo(Employee__c emp) {
            if (emp == null) {
                this.MemberId = 'NONE'; this.MemberName = '(미배정)'; return;
            }
            this.MemberId = emp.Id;
            this.MemberName = emp.Name;
            this.TeamId = emp.Department__c;
            this.TeamName = emp.Department__r?.Name;
            this.IsPlaceholder = emp.IsPlaceholder__c;
            this.JobDesc = (emp.JobLevel__c ?? '') + (String.isNotBlank(emp.JobRole__c) ? '(' + emp.JobRole__c + ')' : '');
        }

        private void setProjectInfo(String pId, String pName) {
            this.ProjectId = pId;
            this.ProjectName = pName;
        }
    }

    // ---------------------------------------------------------
    // 2. Public API - LWC Entry Points
    // ---------------------------------------------------------

    @AuraEnabled
    public static List<AllocationWrapper> getAllocations(String viewMode, String teamId, List<String> projectIds, String year, String probability) {
        if (String.isBlank(year) || String.isBlank(probability)) return new List<AllocationWrapper>();
        Set<Id> oppIds = new Set<Id>();
        if (viewMode == 'project' && projectIds != null) {
            for(String pid : projectIds) oppIds.add((Id)pid);
        }
        return processAllocations(viewMode, teamId, oppIds, year, probability);
    }

    @AuraEnabled(Cacheable=true)
    public static List<AllocationWrapper> getMemberAllocations(String memberId, String year) {
        if (String.isBlank(memberId) || String.isBlank(year)) return new List<AllocationWrapper>();
        return processAllocations('member', memberId, new Set<Id>(), year, null);
    }

    /**
     * @description 일괄 저장 메인 트랜잭션
     */
    @AuraEnabled
    public static void saveAllChanges(List<Map<String, String>> membersToInsert, List<Id> deleteMemberIds, List<Map<String, Object>> mmList) {
        Savepoint sp = Database.setSavepoint();
        try {
            // 1. 멤버 비활성화 (Soft Delete)
            deactivateProjectMembers(deleteMemberIds);

            // 2. 신규 멤버 Upsert 및 ID 매핑 확보
            Map<String, Id> pmKeyMap = upsertProjectMembers(membersToInsert);

            // 3. 공수 데이터 저장 및 유효성 검사
            if (mmList != null && !mmList.isEmpty()) {
                saveMonthlyEstimations(mmList, pmKeyMap, new Set<Id>(deleteMemberIds ?? new List<Id>()));
            }
        } catch (Exception e) {
            Database.rollback(sp);
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------------------------------------------------------
    // 3. Core Logic (Private Helpers)
    // ---------------------------------------------------------

    private static List<AllocationWrapper> processAllocations(String mode, String filterId, Set<Id> oppIds, String year, String probability) {
        List<AllocationWrapper> results = new List<AllocationWrapper>();
        Integer yr = Integer.valueOf(year);

        // 데이터 조회
        List<Employee__c> employeeList = queryEmployees(mode, filterId);
        Map<Id, Employee__c> employeeMap = new Map<Id, Employee__c>(employeeList);
        List<ProjectMember__c> pmList = queryProjectMembers(mode, filterId, oppIds, year, probability, employeeMap.keySet());
        Map<String, MonthlyEstimation__c> meMap = queryMonthlyEstimationMap(new Map<Id, ProjectMember__c>(pmList).keySet(), year);

        // 데이터 조합 (Case 1 & 2)
        Set<Id> assignedEmployeeIds = new Set<Id>();
        Set<Id> projectsWithMembers = new Set<Id>();

        for (ProjectMember__c pm : pmList) {
            assignedEmployeeIds.add(pm.Employee__c);
            projectsWithMembers.add(pm.Opportunity__c);
            for (Integer m = 1; m <= 12; m++) {
                MonthlyEstimation__c me = meMap.get(pm.Id + '_' + m);
                results.add(me != null ? new AllocationWrapper(me) : new AllocationWrapper(pm, yr, m));
            }
        }

        // 예외 행 처리 (Case 3, 4, 5)
        handleEdgeCaseWrappers(results, mode, yr, oppIds, projectsWithMembers, employeeList, assignedEmployeeIds);
        return results;
    }

    // --- 저장 보조 메서드 (DML 통일) ---

    private static void deactivateProjectMembers(List<Id> deleteMemberIds) {
        if (deleteMemberIds == null || deleteMemberIds.isEmpty()) return;
        List<ProjectMember__c> delList = new List<ProjectMember__c>();
        for (Id pid : deleteMemberIds) delList.add(new ProjectMember__c(Id = pid, IsActive__c = false));
        update delList;
    }

    private static Map<String, Id> upsertProjectMembers(List<Map<String, String>> membersToInsert) {
        Map<String, Id> pmKeyMap = new Map<String, Id>();
        if (membersToInsert == null || membersToInsert.isEmpty()) return pmKeyMap;

        List<ProjectMember__c> pmUpsertList = new List<ProjectMember__c>();
        for (Map<String, String> m : membersToInsert) {
            pmUpsertList.add(new ProjectMember__c(
                Opportunity__c = (Id)m.get('ProjectId'),
                Employee__c = (Id)m.get('MemberId'), Role__c = m.get('Role'),
                Grade__c = m.get('Grade'), ProjectMemberExternalKey__c = m.get('PMKey'), IsActive__c = true
            ));
        }
        upsert pmUpsertList ProjectMemberExternalKey__c;
        for(ProjectMember__c pm : pmUpsertList) pmKeyMap.put(pm.ProjectMemberExternalKey__c, pm.Id);
        return pmKeyMap;
    }

    private static void saveMonthlyEstimations(List<Map<String, Object>> mmList, Map<String, Id> pmKeyMap, Set<Id> deactivatingIds) {
        // 부모 ID 보충 조회
        Set<String> neededPmKeys = new Set<String>();
        for (Map<String, Object> mm : mmList) neededPmKeys.add(((String)mm.get('CompositeKey')).substringBeforeLast('_'));
        neededPmKeys.removeAll(pmKeyMap.keySet());
        if (!neededPmKeys.isEmpty()) {
            for (ProjectMember__c pm : [SELECT Id, ProjectMemberExternalKey__c FROM ProjectMember__c WHERE ProjectMemberExternalKey__c IN :neededPmKeys]) {
                pmKeyMap.put(pm.ProjectMemberExternalKey__c, pm.Id);
            }
        }

        List<MonthlyEstimation__c> meUpsertList = new List<MonthlyEstimation__c>();

        Map<String, Decimal> newContractValuesMap = new Map<String, Decimal>();
        Map<String, Decimal> newActualValuesMap = new Map<String, Decimal>();

        for (Map<String, Object> mm : mmList) {
            String cKey = (String)mm.get('CompositeKey');
            Id parentId = pmKeyMap.get(cKey.substringBeforeLast('_'));
            if (parentId == null) continue;

            Decimal contractVal = Decimal.valueOf(String.valueOf(mm.get('ContractMM') ?? 0));
            Decimal actualVal = Decimal.valueOf(String.valueOf(mm.get('ActualMM') ?? 0));

            meUpsertList.add(new MonthlyEstimation__c(
                ProjectMember__c = parentId, AllocationExternalKey__c = cKey,
                ContractMM__c = contractVal, ActualMM__c = actualVal,
                Year__c = String.valueOf(mm.get('Year')),
                Month__c = String.valueOf(mm.get('Month')).leftPad(2, '0')
            ));
            newContractValuesMap.put(cKey, contractVal);
            newActualValuesMap.put(cKey, actualVal);
        }

        // 유효성 검사 (MM 합계 체크)
        validateTotalMM(meUpsertList, newContractValuesMap, newActualValuesMap, deactivatingIds);
        upsert meUpsertList AllocationExternalKey__c;
    }

    /**
 * @description 인당 월별 합계 MM 유효성 검사 전문
 * @param toUpsert 저장 예정인 MonthlyEstimation__c 리스트
 * @param newContractMap 화면에서 넘어온 새 계약공수 맵 (Key: ExternalKey)
 * @param newActualMap 화면에서 넘어온 새 실제공수 맵 (Key: ExternalKey)
 * @param deactivatingIds 화면에서 삭제(Soft Delete)된 프로젝트 멤버 ID 셋
 */
    private static void validateTotalMM(
        List<MonthlyEstimation__c> toUpsert,
        Map<String, Decimal> newContractMap,
        Map<String, Decimal> newActualMap,
        Set<Id> deactivatingIds
    ) {
        // 1. 검증에 필요한 직원 및 연도 정보 추출
        Set<Id> pmIds = new Set<Id>();
        Set<String> targetYears = new Set<String>();
        for(MonthlyEstimation__c me : toUpsert) {
            pmIds.add(me.ProjectMember__c);
            targetYears.add(me.Year__c);
        }

        // 직원 정보(성명 포함) 조회
        Map<Id, ProjectMember__c> pmInfoMap = new Map<Id, ProjectMember__c>([
            SELECT Id, Employee__c, Employee__r.Name
            FROM ProjectMember__c
            WHERE Id IN :pmIds
        ]);

        Set<Id> empIds = new Set<Id>();
        for(ProjectMember__c pm : pmInfoMap.values()) empIds.add(pm.Employee__c);

        // 2. 최종 합산용 맵 (Key: EmployeeId_Year_Month)
        Map<String, Decimal> finalContractSumMap = new Map<String, Decimal>();
        Map<String, Decimal> finalActualSumMap = new Map<String, Decimal>();

        /**
         * [핵심 로직] DB의 기존 데이터를 읽어오되,
         * 현재 수정 중인 레코드는 화면의 값으로 대체하고, 삭제 대상은 제외함.
         */
        for (MonthlyEstimation__c dbMe : [
            SELECT ContractMM__c, ActualMM__c, Year__c, Month__c, AllocationExternalKey__c,
                ProjectMember__r.Employee__c
            FROM MonthlyEstimation__c
            WHERE ProjectMember__r.Employee__c IN :empIds
            AND Year__c IN :targetYears
            AND ProjectMember__r.IsActive__c = TRUE
            AND ProjectMember__c NOT IN :deactivatingIds // 삭제 대상 제외
        ]) {
            String empKey = dbMe.ProjectMember__r.Employee__c + '_' + dbMe.Year__c + '_' + dbMe.Month__c;
            String extKey = dbMe.AllocationExternalKey__c;

            // 계약공수: 수정본이 있으면 새 값, 없으면 기존 DB값
            Decimal cVal = newContractMap.containsKey(extKey) ? newContractMap.get(extKey) : (dbMe.ContractMM__c ?? 0);
            finalContractSumMap.put(empKey, (finalContractSumMap.get(empKey) ?? 0) + cVal);

            // 실제공수: 수정본이 있으면 새 값, 없으면 기존 DB값
            Decimal aVal = newActualMap.containsKey(extKey) ? newActualMap.get(extKey) : (dbMe.ActualMM__c ?? 0);
            finalActualSumMap.put(empKey, (finalActualSumMap.get(empKey) ?? 0) + aVal);

            // 처리된 수정본은 Map에서 제거 (신규 추가 데이터만 남기기 위함)
            newContractMap.remove(extKey);
            newActualMap.remove(extKey);
        }

        // 3. DB에 없던 완전 신규 추가 공수 데이터 합산
        for (MonthlyEstimation__c newMe : toUpsert) {
            if (newContractMap.containsKey(newMe.AllocationExternalKey__c)) {
                String empKey = pmInfoMap.get(newMe.ProjectMember__c).Employee__c + '_' + newMe.Year__c + '_' + newMe.Month__c;

                finalContractSumMap.put(empKey, (finalContractSumMap.get(empKey) ?? 0) + (newContractMap.get(newMe.AllocationExternalKey__c) ?? 0));
                finalActualSumMap.put(empKey, (finalActualSumMap.get(empKey) ?? 0) + (newActualMap.get(newMe.AllocationExternalKey__c) ?? 0));

                // 중복 합산 방지
                newContractMap.remove(newMe.AllocationExternalKey__c);
            }
        }

        // 4. 최종 검증 및 에러 메시지 생성
        List<String> errorMessages = new List<String>();
        // 중복 체크 방지용 셋
        Set<String> checkedKeys = new Set<String>();

        for (MonthlyEstimation__c me : toUpsert) {
            ProjectMember__c pm = pmInfoMap.get(me.ProjectMember__c);
            String empKey = pm.Employee__c + '_' + me.Year__c + '_' + me.Month__c;

            if (checkedKeys.contains(empKey)) continue;

            Decimal totalContract = finalContractSumMap.get(empKey) ?? 0;
            Decimal totalActual = finalActualSumMap.get(empKey) ?? 0;

            // 계약공수 1.0 초과 체크 (부동 소수점 오차 감안)
            if (totalContract > 1.0001) {
                errorMessages.add(String.format('{0}님 {1}월 [계약공수] 초과: {2} MM',
                    new List<Object>{ pm.Employee__r.Name, me.Month__c, totalContract.setScale(2) }));
            }

            // 실제공수 1.0 초과 체크
            if (totalActual > 1.0001) {
                errorMessages.add(String.format('{0}님 {1}월 [실제공수] 초과: {2} MM',
                    new List<Object>{ pm.Employee__r.Name, me.Month__c, totalActual.setScale(2) }));
            }

            checkedKeys.add(empKey);
        }

        // 위반 사항이 있을 경우 통합 메시지 전송
        if (!errorMessages.isEmpty()) {
            String finalMsg = '인당 월별 공수 합계는 1.0을 초과할 수 없습니다: \n• ' + String.join(errorMessages, '\n• ');
            AuraHandledException ex = new AuraHandledException(finalMsg);
            ex.setMessage(finalMsg);
            throw ex;
        }
    }

    // --- 조회 보조 메서드 ---

    private static List<Employee__c> queryEmployees(String mode, String filterId) {
        if (!mode.contains('team') && mode != 'member') return new List<Employee__c>();
        String q = 'SELECT Id, Name, Department__c, JobRole__c, JobLevel__c, Fm_SortKey__c, IsPlaceholder__c, Department__r.Name FROM Employee__c WHERE IsActive__c = TRUE ';
        if (mode == 'member') q += 'AND Id = :filterId LIMIT 1';
        else q += 'AND (Department__c = :filterId OR Department__r.ParentDepartment__c = :filterId) ORDER BY Department__r.Fm_SortKey__c, Fm_SortKey__c';
        return Database.query(q);
    }

    private static List<ProjectMember__c> queryProjectMembers(String mode, String filterId, Set<Id> oppIds, String year, String probability, Set<Id> empIds) {
        String query = 'SELECT Id, Employee__c, Opportunity__c, Role__c, Grade__c, Fm_SortKey__c, ProjectMemberExternalKey__c, ' +
            'Employee__r.Name, Employee__r.Department__c, Employee__r.JobRole__c, Employee__r.JobLevel__c, Employee__r.IsPlaceholder__c, ' +
            'Employee__r.Department__r.Name, Opportunity__r.Name, Opportunity__r.Probability__c ' +
            'FROM ProjectMember__c WHERE IsActive__c = true AND Employee__r.IsActive__c = true ';
        if (mode.contains('team') || mode == 'member') query += 'AND Id IN (SELECT ProjectMember__c FROM MonthlyEstimation__c WHERE Year__c = :year) ';
        if (mode.contains('team')) query += 'AND Employee__c IN :empIds ';
        else if (mode == 'project') query += 'AND Opportunity__c IN :oppIds ';
        else if (mode == 'member') query += 'AND Employee__c = :filterId ';
        if (String.isNotBlank(probability) && probability != 'ALL') {
            if (probability == 'WON') query += ' AND Opportunity__r.StageName = \'Closed Won\' ';
            else if (probability == 'NONE') query += ' AND Opportunity__r.Probability__c = null AND Opportunity__r.StageName != \'Closed Won\' ';
            else query += ' AND Opportunity__r.Probability__c = :probability AND Opportunity__r.StageName != \'Closed Won\' ';
        }
        query += mode.contains('team') ? 'ORDER BY Employee__r.Department__r.Fm_SortKey__c, Employee__r.Fm_SortKey__c ' : 'ORDER BY Fm_SortKey__c ';
        return Database.query(query);
    }

    private static Map<String, MonthlyEstimation__c> queryMonthlyEstimationMap(Set<Id> pmIds, String year) {
        Map<String, MonthlyEstimation__c> res = new Map<String, MonthlyEstimation__c>();
        if (pmIds.isEmpty()) return res;
        for (MonthlyEstimation__c me : [
            SELECT Id, ContractMM__c, ActualMM__c, Month__c, Year__c, AllocationExternalKey__c, Fm_WeightedActualMM__c, Fm_WeightedContractMM__c,
                ProjectMember__c, ProjectMember__r.Role__c, ProjectMember__r.Grade__c, ProjectMember__r.Opportunity__c, ProjectMember__r.Opportunity__r.Name,
                ProjectMember__r.Opportunity__r.Probability__c, ProjectMember__r.Employee__c, ProjectMember__r.Employee__r.Name, ProjectMember__r.Employee__r.Department__c,
                ProjectMember__r.Employee__r.Department__r.Name, ProjectMember__r.Employee__r.JobRole__c, ProjectMember__r.Employee__r.JobLevel__c, ProjectMember__r.Employee__r.IsPlaceholder__c
            FROM MonthlyEstimation__c WHERE ProjectMember__c IN :pmIds AND Year__c = :year
        ]) {
            res.put(me.ProjectMember__c + '_' + Integer.valueOf(me.Month__c), me);
        }
        return res;
    }

    /**
 * @description 가상 행(데이터가 없는 프로젝트/직원)을 생성하는 로직 개선
 */
    private static void handleEdgeCaseWrappers(
        List<AllocationWrapper> results,
        String mode,
        Integer yr,
        Set<Id> oppIds,
        Set<Id> projectsWithMembers,
        List<Employee__c> employeeList,
        Set<Id> assignedEmployeeIds
    ) {
        // 1. [프로젝트 뷰] 선택된 프로젝트 중 멤버가 한 명도 없는 프로젝트 처리
        if (mode == 'project') {
            // null 체크 및 비어있을 경우 방어 로직
            if (oppIds == null || oppIds.isEmpty()) return;

            for (Opportunity opp : [SELECT Id, Name, Probability__c FROM Opportunity WHERE Id IN :oppIds]) {
                // 이미 결과 리스트에 멤버가 있는 프로젝트는 제외
                if (!projectsWithMembers.contains(opp.Id)) {
                    for (Integer m = 1; m <= 12; m++) {
                        results.add(new AllocationWrapper(opp, yr, m));
                    }
                }
            }
        }
        // 2. [팀 뷰] 부서원 중 프로젝트 할당(MonthlyEstimation)이 하나도 없는 직원 처리
        else if (mode.contains('team')) {
            if (employeeList == null || employeeList.isEmpty()) return;

            for (Employee__c emp : employeeList) {
                // 할당된 직원 Set에 포함되어 있지 않은 경우만 가상 행 생성
                if (!assignedEmployeeIds.contains(emp.Id)) {
                    for (Integer m = 1; m <= 12; m++) {
                        results.add(new AllocationWrapper(emp, yr, m));
                    }
                }
            }
        }
        // 3. [멤버 뷰] 1인 조회 시 데이터가 아무것도 없는 경우 (UI 뼈대 유지용)
        else if (mode == 'member' && results.isEmpty()) {
            if (employeeList != null && !employeeList.isEmpty()) {
                for (Integer m = 1; m <= 12; m++) {
                    results.add(new AllocationWrapper(employeeList[0], yr, m));
                }
            }
        }
    }

    // ---------------------------------------------------------
    // 4. Metadata & Picklists
    // ---------------------------------------------------------

    @AuraEnabled(Cacheable=true)
    public static List<OptionWrapper> getProjectOptions(String year, String probability) {
        if (String.isBlank(year)) return new List<OptionWrapper>();
        Integer targetYear = Integer.valueOf(year);
        Date startDate = Date.newInstance(targetYear - 1, 1, 1);
        Date endDate = Date.newInstance(targetYear, 12, 31);

        String query = 'SELECT Id, Name, Probability__c, CloseDate, StageName FROM Opportunity WHERE CloseDate >= :startDate AND CloseDate <= :endDate ';
        if (String.isNotBlank(probability)) {
            if (probability == 'WON') query += ' AND StageName = \'Closed Won\' ';
            else if (probability == 'NONE') query += ' AND Probability__c = null AND StageName != \'Closed Won\' ';
            else if (probability != 'ALL') query += ' AND Probability__c = :probability AND StageName != \'Closed Won\' ';
        }
        List<OptionWrapper> options = new List<OptionWrapper>();
        for (Opportunity opp : Database.query(query + ' ORDER BY CloseDate DESC LIMIT 200')) {
            String probLabel = opp.StageName == 'Closed Won' ? '(완료)' : (opp.Probability__c != null ? '(' + opp.Probability__c + ')' : '');
            options.add(new OptionWrapper('[' + opp.CloseDate.year() + ']' + probLabel + ' ' + opp.Name, opp.Id));
        }
        return options;
    }

    public class OptionWrapper {
        @AuraEnabled public String label; @AuraEnabled public String value;
        public OptionWrapper(String l, String v) { this.label = l; this.value = v; }
    }

    @AuraEnabled(Cacheable=true)
    public static Map<String, Object> getInitMetadata() {
        List<OptionWrapper> probs = new List<OptionWrapper>{ new OptionWrapper('전체', 'ALL'), new OptionWrapper('완료', 'WON') };
        probs.addAll(getPicklistOptions('Opportunity', 'Probability__c'));
        probs.add(new OptionWrapper('미지정', 'NONE'));
        return new Map<String, Object>{
            'years' => getPicklistOptions('MonthlyEstimation__c', 'Year__c'),
            'divisions' => getDepartmentOptions(null, false), 'probabilities' => probs
        };
    }

    @AuraEnabled(Cacheable=true)
    public static List<OptionWrapper> getDepartmentOptions(Id parentDeptId, Boolean includeAll) {
        List<OptionWrapper> opts = new List<OptionWrapper>();
        if (includeAll && parentDeptId != null) opts.add(new OptionWrapper('전체', parentDeptId));
        for (Department__c d : [SELECT Id, Name FROM Department__c WHERE ParentDepartment__c = :parentDeptId ORDER BY Fm_SortKey__c]) opts.add(new OptionWrapper(d.Name, d.Id));
        return opts;
    }

    @AuraEnabled(Cacheable=true)
    public static List<OptionWrapper> getPicklistOptions(String objectName, String fieldName) {
        List<OptionWrapper> opts = new List<OptionWrapper>();
        Schema.SObjectType sType = Schema.getGlobalDescribe().get(objectName);
        for (Schema.PicklistEntry entry : sType.getDescribe().fields.getMap().get(fieldName).getDescribe().getPicklistValues()) {
            if (entry.isActive()) opts.add(new OptionWrapper(entry.getLabel(), entry.getValue()));
        }
        return opts;
    }
}