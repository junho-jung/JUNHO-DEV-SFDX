/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-12-29      jh.jung           Created
*/
/**
 * @Description: 리소스 관리 대시보드 데이터 컨트롤러 (Matrix 조직 대응)
 * @Author: jh.jung
 */
public with sharing class New_PMS_ResourceManagementController {

    public class AllocationWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String CompositeKey;
        @AuraEnabled public String ProjectMemberId;
        @AuraEnabled public String MemberId;
        @AuraEnabled public String MemberName;
        @AuraEnabled public String TeamId;
        @AuraEnabled public String TeamName;
        @AuraEnabled public String ProjectId;
        @AuraEnabled public String ProjectName;
        @AuraEnabled public String Role;
        @AuraEnabled public Date TargetMonth;
        @AuraEnabled public Decimal ContractMM;
        @AuraEnabled public Decimal ActualMM;
    }

    private class ProjectMemberMock {
        public String mId, mName, pId, pName, role, tId, tName;
        public Decimal baseMM;
        public Integer startM, endM;

        public ProjectMemberMock(String mId, String mName, String pId, String pName, String role, String tId, String tName, Decimal mm, Integer s, Integer e) {
            this.mId = mId;
            this.mName = mName;
            this.pId = pId;
            this.pName = pName;
            this.role = role;
            this.tId = tId;
            this.tName = tName;
            this.baseMM = mm;
            this.startM = s;
            this.endM = e;
        }
    }

    private static List<ProjectMemberMock> DB_MOCK_PROJECT_MEMBERS;

    static {
        DB_MOCK_PROJECT_MEMBERS = new List<ProjectMemberMock>();
        Map<String, String> pMap = new Map<String, String>{
              'P01'=>'만트럭'
            , 'P02'=>'코오롱'
            , 'P03'=>'포스코'
            , 'P04'=>'클래시스'
            , 'P05'=>'현대자동차'
            , 'P06'=>'기아자동차'
            , 'P07'=>'커넥스 구축'
            , 'P08'=>'커넥스 운영'
            , 'P09'=>'데이터 이쿠'
            , 'P10'=>'태블로'
            , 'P11'=>'LLM'
        };

        // 1. 솔루션사업팀
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_SS_1', '강팀장', 'P01', pMap.get('P01'), 'PM', 'T_SS', '솔루션사업팀', 0.5, 1, 3));
//        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_SS_1', '강팀장', 'P02', pMap.get('P02'), 'PM', 'T_SS', '솔루션사업팀', 0.5, 3, 12));
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_SS_1', '강팀장', 'P03', pMap.get('P03'), 'PM', 'T_SS', '솔루션사업팀', 0.5, 5, 8));
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_SS_1', '강팀장', 'P05', pMap.get('P05'), 'PM', 'T_SS', '솔루션사업팀', 0.5, 1, 6));
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_SS_1', '강팀장', 'P11', pMap.get('P11'), 'PM', 'T_SS', '솔루션사업팀', 1, 9, 12));

        // 2. SF1팀
        for(Integer i=1; i<=5; i++) {
            String mid = 'M_SF1_'+i; String mname = 'SF1_멤버'+i;
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P01', pMap.get('P01'), 'Dev', 'T_SF1', 'SF1팀', 1.0, 1, 3));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P02', pMap.get('P02'), 'Dev', 'T_SF1', 'SF1팀', 0.5, 4, 12));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P03', pMap.get('P03'), 'Dev', 'T_SF1', 'SF1팀', 0.5, 5, 8));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P04', pMap.get('P04'), 'Admin', 'T_SF1', 'SF1팀', 0.5, 9, 12));
        }
        // 3. SF2팀
        for(Integer i=1; i<=5; i++) {
            String mid = 'M_SF2_'+i; String mname = 'SF2_멤버'+i;
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P05', pMap.get('P05'), 'Dev', 'T_SF2', 'SF2팀', 0.5, 1, 6));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P06', pMap.get('P06'), 'Dev', 'T_SF2', 'SF2팀', 0.5, 4, 10));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P07', pMap.get('P07'), 'Dev', 'T_SF2', 'SF2팀', 0.5, 8, 12));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P08', pMap.get('P08'), 'Dev', 'T_SF2', 'SF2팀', 0.5, 8, 12));
        }

        // 4. AX솔루션팀
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_AX_1', 'AX_멤버1', 'P01', pMap.get('P01'), 'BI', 'T_AX', 'AX솔루션팀', 0.5, 1, 3));
        DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock('M_AX_1', 'AX_멤버1', 'P02', pMap.get('P02'), 'BI', 'T_AX', 'AX솔루션팀', 0.5, 4, 12));
        for(Integer i=1; i<=5; i++) {
            String mid = 'M_AX_'+i; String mname = 'AX_멤버'+i;
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P09', pMap.get('P09'), 'AI', 'T_AX', 'AX솔루션팀', 0.5, 1, 3));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P10', pMap.get('P10'), 'AI', 'T_AX', 'AX솔루션팀', 0.5, 5, 8));
            DB_MOCK_PROJECT_MEMBERS.add(new ProjectMemberMock(mid, mname, 'P11', pMap.get('P11'), 'AI', 'T_AX', 'AX솔루션팀', 1, 9, 12));
        }
    }

    @AuraEnabled(Cacheable=true)
    public static List<AllocationWrapper> getAllocations(String viewMode, String teamId, List<String> projectIds, String year) {
        List<AllocationWrapper> results = new List<AllocationWrapper>();
        if (String.isBlank(year)) return results;
        Integer yr = Integer.valueOf(year);
        Set<String> pIdSet = (projectIds != null) ? new Set<String>(projectIds) : new Set<String>();

        for (ProjectMemberMock pm : DB_MOCK_PROJECT_MEMBERS) {
            if (viewMode == 'team' && String.isNotBlank(teamId) && pm.tId != teamId) continue;
            if (viewMode == 'project' && !pIdSet.isEmpty() && !pIdSet.contains(pm.pId)) continue;
            if (viewMode == 'project' && pIdSet.isEmpty()) break;

            for (Integer m = 1; m <= 12; m++) {
                Boolean isActive = (m >= pm.startM && m <= pm.endM);
                AllocationWrapper row = new AllocationWrapper();
                row.Id = 'mock_' + pm.mId + '_' + pm.pId + '_' + m;
                row.CompositeKey = pm.mId + '_' + pm.pId + '_' + m;
                row.ProjectMemberId = pm.mId + '_' + pm.pId;
                row.MemberId = pm.mId;
                row.MemberName = pm.mName;
                row.TeamId = pm.tId;
                row.TeamName = pm.tName;
                row.ProjectId = pm.pId;
                row.ProjectName = pm.pName;
                row.Role = pm.role;
                row.TargetMonth = Date.newInstance(yr, m, 1);
                row.ContractMM = isActive ? pm.baseMM : 0.0;
                row.ActualMM = isActive ? pm.baseMM : 0.0;
                if('BI'.equals(pm.role) && row.ContractMM != 0) row.ActualMM += 0.5;
                results.add(row);
            }
        }
        return results;
    }
//    @AuraEnabled(Cacheable=true)
//    public static List<AllocationWrapper> getAllocations(String viewMode, String teamId, List<String> projectIds, String year) {
//        List<AllocationWrapper> results = new List<AllocationWrapper>();
//        if (String.isBlank(year)) return results;
//        Integer yr = Integer.valueOf(year);
//        Set<String> pIdSet = (projectIds != null) ? new Set<String>(projectIds) : new Set<String>();
//
//        for (ProjectMemberMock pm : DB_MOCK_PROJECT_MEMBERS) {
//            if (viewMode == 'team' && String.isNotBlank(teamId) && pm.tId != teamId) continue;
//            if (viewMode == 'project' && !pIdSet.isEmpty() && !pIdSet.contains(pm.pId)) continue;
//            if (viewMode == 'project' && pIdSet.isEmpty()) break;
//
//            for (Integer m = 1; m <= 12; m++) {
//                Boolean isActive = (m >= pm.startM && m <= pm.endM);
//                AllocationWrapper row = new AllocationWrapper();
//                row.Id = 'mock_' + pm.mId + '_' + pm.pId + '_' + m;
//                row.CompositeKey = pm.mId + '_' + pm.pId + '_' + m;
//                row.ProjectMemberId = pm.mId + '_' + pm.pId;
//                row.MemberId = pm.mId;
//                row.MemberName = pm.mName;
//                row.TeamId = pm.tId;
//                row.TeamName = pm.tName;
//                row.ProjectId = pm.pId;
//                row.ProjectName = pm.pName;
//                row.Role = pm.role;
//                row.TargetMonth = Date.newInstance(yr, m, 1);
//                row.ContractMM = isActive ? pm.baseMM : 0.0;
//                row.ActualMM = isActive ? pm.baseMM : 0.0;
//                if('BI'.equals(pm.role) && row.ContractMM != 0) row.ActualMM += 0.5;
//                results.add(row);
//            }
//        }
//        return results;
//    }
}