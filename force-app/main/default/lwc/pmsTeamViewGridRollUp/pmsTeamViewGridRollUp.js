/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-14      jh.jung           Created
 */
import {api, LightningElement, track} from 'lwc';

export default class PmsTeamViewGridRollUp extends LightningElement {

  @api allocations = [];
  @api currentHalf;

  @track isModalOpen = false;
  @track modalData = [];

  selectedMemberName;
  selectedMonth;

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

      const month = item.Month;
      if (!this.monthNums.includes(month)) return;

      // 1. 팀 초기화
      if (!teamMap[item.TeamId]) {
        teamMap[item.TeamId] = { id: item.TeamId, name: item.TeamName, members: {} };
      }

      // 2. 멤버 초기화
      if (!teamMap[item.TeamId].members[item.MemberId]) {
        teamMap[item.TeamId].members[item.MemberId] = {
          id: item.MemberId,
          name: item.MemberName,
          role: item.JobDesc,
          monthly: {} // 월별 합산 데이터를 담을 객체
        };
      }

      const member = teamMap[item.TeamId].members[item.MemberId];

      // 3. 월별 합산 로직 (Rollup)
      if (!member.monthly[month]) {
        member.monthly[month] = { totalActual: 0, totalContract: 0 };
      }

      const actualVal = item.ActualMM;
      const contractVal = item.ContractMM;

      member.monthly[month].totalActual += (actualVal || 0);
      member.monthly[month].totalContract += (contractVal || 0);
    });

    const result = Object.values(teamMap).map(team => ({
      ...team,
      memberList: Object.values(team.members).map(mem => ({
        ...mem,
        monthlyData: this.monthNums.map(m => {
          const data = mem.monthly[m] || { totalActual: 0, totalContract: 0 };

          console.log(JSON.stringify({
            month: m,
            contract: data.totalContract.toFixed(1),
            actual: data.totalActual.toFixed(1),
            cellClass: `cell-mm-data pointer-cell ${this.getHeatmapClass(data.totalActual)}`
          }))
          return {
            month: m,
            contract: data.totalContract.toFixed(1),
            actual: data.totalActual.toFixed(1),
            cellClass: `cell-mm-data pointer-cell ${this.getHeatmapClass(data.totalActual)}`
          };
        })
      }))
    }));

    return result;

    // 최종 리스트 변환
    // return Object.values(teamMap).map(team => ({
    //   ...team,
    //   memberList: Object.values(team.members).map(mem => ({
    //     ...mem,
    //     monthlyData: this.monthNums.map(m => {
    //       const data = mem.monthly[m] || { totalActual: 0, isDirty: false };
    //       return {
    //         month: m,
    //         totalActual: data.totalActual.toFixed(1), // 소수점 첫째자리 고정
    //         isDirty: data.isDirty,
    //         cellClass: `cell-mm-data pointer-cell ${this.getHeatmapClass(data.totalActual)}`
    //       };
    //     })
    //   }))
    // }));
  }

  handleCellClick(event) {
    const { memberId, month, memberName } = event.currentTarget.dataset;
    this.selectedMemberName = memberName;
    this.selectedMonth = month;

    console.log('memberId ::: ' + memberId);
    console.log('month ::: ' + month);
    console.log('memberName ::: ' + memberName);

    // 원본 allocations에서 해당 멤버/월의 모든 프로젝트 레코드를 찾음
    this.modalData = this.allocations
      .filter(a => a.MemberId === memberId && a.Month == month)
      .map(a => ({
        ...a,
        // 현재 수정 중인 값이 있다면 반영하여 모달에 표시
        contract: a.ContractMM,
        actual: a.ActualMM
      }));

    console.log('modalData ::: ' + JSON.stringify(this.modalData))

    if (this.modalData.length > 0) {
      this.isModalOpen = true;
    }
  }

  // 합계 수치에 따른 배경색 결정
  getHeatmapClass(actual) {
    if (actual === 0) return 'status-none';
    if (actual < 0.3) return 'status-low';      // 저가동 (하늘색)
    if (actual <= 0.7) return 'status-normal';  // 적정 (초록색)
    return 'status-over';                       // 과부하 (빨간색)
  }

  closeModal() {
    this.isModalOpen = false;
  }
}