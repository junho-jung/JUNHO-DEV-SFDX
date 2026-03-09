/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2025-12-29      jh.jung           Created
 */
import { LightningElement, api } from 'lwc';

export default class NewPmsTeamViewGrid extends LightningElement {
  @api allocations = [];
  @api currentHalf;

  get monthNums() {
    // return this.currentHalf === 'H1' ? [1, 2, 3, 4, 5, 6] : [7, 8, 9, 10, 11, 12];
    return this.currentHalf === 'H1' ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : [1, 2, 3, 4, 5, 6];
  }

  get monthLabels() {
    return this.monthNums.map(m => `${m}월`);
  }

  get formattedData() {
    if (!this.allocations) return [];

    const teamMap = {};

    this.allocations.forEach(item => {
      const month = new Date(item.TargetMonth).getMonth() + 1;
      if (!this.monthNums.includes(month)) return;

      // 1. 팀 그룹화
      if (!teamMap[item.TeamId]) {
        teamMap[item.TeamId] = { id: item.TeamId, name: item.TeamName, members: {} };
      }

      // 2. 멤버 그룹화
      if (!teamMap[item.TeamId].members[item.MemberId]) {
        teamMap[item.TeamId].members[item.MemberId] = {
          id: item.MemberId,
          name: item.MemberName,
          role: item.Role,
          projectList: [],
          projectNames: new Set(),
          monthly: {}
        };
      }

      const member = teamMap[item.TeamId].members[item.MemberId];

      // 왼쪽 프로젝트 리스트에는 '한 번이라도 투입이 있는' 프로젝트만 등록
      if (!member.projectNames.has(item.ProjectName)) {
        member.projectNames.add(item.ProjectName);
        member.projectList.push({ id: item.ProjectId, name: item.ProjectName });
      }

      // 3. 월별 데이터 초기화
      if (!member.monthly[month]) {
        member.monthly[month] = { projects: [], totalActual: 0 };
      }

      // 공수가 없으면 isMM = false
      member.monthly[month].projects.push({
        id: item.ProjectId,
        name: item.ProjectName,
        contract: item.ContractMM.toFixed(1),
        actual: item.ActualMM.toFixed(1),
        isMM: (item.ContractMM > 0 || item.ActualMM > 0)
      });

      // 셀 배경색 계산을 위한 합계는 0이어도 계속 누적
      member.monthly[month].totalActual += item.ActualMM;
    });

    return Object.values(teamMap).map(team => ({
      ...team,
      memberList: Object.values(team.members).map(mem => ({
        ...mem,
        monthlyData: this.monthNums.map(m => {
          const data = mem.monthly[m] || { projects: [], totalActual: 0 };
          return {
            month: m,
            projects: data.projects,
            // 셀 전체 배경색을 결정하는 클래스
            cellClass: `cell-mm-data ${this.getHeatmapClass(data.totalActual)}`
          };
        })
      }))
    }));
  }

  // 합계 수치에 따른 배경색 결정
  getHeatmapClass(actual) {
    if (actual === 0) return 'status-none';
    if (actual < 0.3) return 'status-low';      // 저가동 (하늘색)
    if (actual <= 0.7) return 'status-normal';  // 적정 (초록색)
    return 'status-over';                       // 과부하 (빨간색)
  }
}