/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-06      jh.jung           Created
 1.1      2026-01-27      jh.jung           Refactoring / Commenting
 */

import { api, LightningElement } from 'lwc';

/**
 * @description 팀별 리소스 가동률(Heatmap) 및 투입 현황을 그리드 형태로 시각화하는 컴포넌트
 */
export default class PmsTeamViewGrid extends LightningElement {

  // -------------------------------------------------------------------------
  // [1] Properties & State: 외부 입력 및 초기화
  // -------------------------------------------------------------------------

  @api allocations = [];      // 부모로부터 전달받는 전체 투입 데이터 (Array)
  @api currentHalf;           // 상반기(H1) / 하반기(H2) 구분 플래그
  @api targetMemberId;        // 특정 멤버 필터링 시 사용되는 멤버 식별자
  @api hideTeamHeader = false; // 팀 헤더 노출 제어 옵션

  // -------------------------------------------------------------------------
  // [2] Getters: UI 표현을 위한 계산된 속성
  // -------------------------------------------------------------------------

  /** @description 화면에 표시할 월(Month) 숫자 리스트 (현재 로직상 전체 12개월 반환) */
  get monthNums() {
    return this.currentHalf === 'H1' ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : [1, 2, 3, 4, 5, 6];
  }

  /** @description 그리드 헤더용 월 라벨 (예: "1월", "2월"...) */
  get monthLabels() {
    return this.monthNums.map(m => `${m}월`);
  }

  /** * @description [핵심 관제탑] 전체 데이터를 가공하여 UI 템플릿에 최적화된 형태로 반환
   * 처리 순서: 데이터 그룹화(Map) -> UI 모델 변환(Array)
   */
  get formattedData() {
    if (!this.allocations || this.allocations.length === 0) return [];

    // 1단계: 원본 배열을 팀-멤버-월 단위의 중첩 객체 구조로 그룹화
    const teamMap = this.groupDataByTeamAndMember();

    // 2단계: 그룹화된 데이터를 기반으로 통계 계산 및 UI 스타일(Heatmap) 확정
    return this.transformToUiModel(teamMap);
  }

  // -------------------------------------------------------------------------
  // [3] Data Processing: 그룹화 로직 (Private)
  // -------------------------------------------------------------------------

  /** * @description 데이터를 팀과 멤버별로 트리 구조로 재편성
   * @returns {Object} teamMap
   */
  groupDataByTeamAndMember() {
    const teamMap = {};

    this.allocations.forEach(item => {
      // 필터링: 특정 멤버 검색 시 해당 데이터 외 skip
      if (this.targetMemberId && item.MemberId !== this.targetMemberId) return;

      const month = item.Month;
      if (!this.monthNums.includes(month)) return;

      // 팀(Team) 레벨 초기화 및 할당
      if (!teamMap[item.TeamId]) {
        teamMap[item.TeamId] = this.initializeTeamObject(item.TeamId, item.TeamName);
      }
      const team = teamMap[item.TeamId];

      // 멤버(Member) 레벨 초기화 및 할당
      if (!team.members[item.MemberId]) {
        team.members[item.MemberId] = this.initializeMemberObject(item);
      }
      const member = team.members[item.MemberId];

      // 팀 내 고유 멤버 식별 (가동률 계산의 분모가 됨)
      team.memberIds.add(item.MemberId);

      // 프로젝트 목록 관리 (중복 방지)
      if (!member.projectNames.has(item.ProjectName)) {
        member.projectNames.add(item.ProjectName);
        member.projectList.push({ id: item.ProjectId, name: item.ProjectName });
      }

      // 월별 수치(Contract/Actual) 누적 처리
      this.accumulateMonthlyData(member, team, item, month);
    });

    return teamMap;
  }

  // -------------------------------------------------------------------------
  // [4] Transformation: UI 모델 생성 및 통계 계산 (Private)
  // -------------------------------------------------------------------------

  /** * @description 그룹화된 맵을 배열로 변환하고 가동률/총계 산출
   * @param {Object} teamMap
   * @returns {Array} UI 전용 데이터 모델
   */
  transformToUiModel(teamMap) {
    return Object.values(teamMap).map(team => {
      const memberCount = team.memberIds.size;
      const monthCount = this.monthNums.length;
      const totalCapacity = memberCount * monthCount; // 총 가용 M/M (인원수 * 개월수)

      // 팀 레벨 전체 총계 합산
      const totalC = Object.values(team.colContractTotals).reduce((a, b) => a + b, 0);
      const totalA = Object.values(team.colActualTotals).reduce((a, b) => a + b, 0);

      return {
        ...team,
        memberCount,
        totalCapacity,
        // 팀 전체 평균 가동률 정보 (Footer 영역)
        grandTotal: this.calculateUtilization(totalC, totalA, totalCapacity),

        // 팀 월별 합계 (그리드 하단 소계 행)
        colTotalsData: this.monthNums.map(m => {
          const cTotal = team.colContractTotals[m] || 0;
          const aTotal = team.colActualTotals[m] || 0;
          return {
            month: m,
            contract: cTotal.toFixed(1),
            actual: aTotal.toFixed(1),
            ...this.calculateUtilization(cTotal, aTotal, memberCount)
          };
        }),

        // 팀 내 멤버 리스트 가공 (그리드 본문 행)
        memberList: Object.values(team.members).map(mem => ({
          ...mem,
          rowContractTotal: mem.rowContractTotal.toFixed(1),
          rowActualTotal: mem.rowActualTotal.toFixed(1),
          monthlyData: this.monthNums.map(m => {
            const data = mem.monthly[m] || { projects: [], totalActual: 0 };
            return {
              month: m,
              projects: data.projects,
              // 실제 가동 수치에 따른 히트맵 배경색 결정
              cellClass: `cell-mm-data ${this.getHeatmapClass(data.totalActual)}`
            };
          })
        }))
      };
    });
  }

  // -------------------------------------------------------------------------
  // [5] Helper Methods: 재사용 가능한 유틸리티
  // -------------------------------------------------------------------------

  /** @description 팀 단위 데이터 구조 초기화 */
  initializeTeamObject(id, name) {
    return {
      id, name, members: {},
      colContractTotals: {}, colActualTotals: {},
      memberIds: new Set()
    };
  }

  /** @description 멤버 단위 데이터 구조 초기화 */
  initializeMemberObject(item) {
    return {
      id: item.MemberId, name: item.MemberName, role: item.JobDesc,
      projectList: [], projectNames: new Set(), monthly: {},
      rowContractTotal: 0, rowActualTotal: 0
    };
  }

  /** @description 월별 및 인원별 공수 데이터를 누적 합산 */
  accumulateMonthlyData(member, team, item, month) {
    if (!member.monthly[month]) {
      member.monthly[month] = { projects: [], totalContract: 0, totalActual: 0 };
    }

    member.monthly[month].projects.push({
      id: item.ProjectId, name: item.ProjectName,
      contract: item.ContractMM.toFixed(1),
      actual: item.ActualMM.toFixed(1),
      isMM: (item.ContractMM > 0 || item.ActualMM > 0)
    });

    // 멤버별 월 합계 및 행 전체 합계 누적
    member.monthly[month].totalContract += item.ContractMM;
    member.monthly[month].totalActual += item.ActualMM;
    member.rowContractTotal += item.ContractMM;
    member.rowActualTotal += item.ActualMM;

    // 팀별 월 전체 합계(열 합계) 누적
    team.colContractTotals[month] = (team.colContractTotals[month] || 0) + item.ContractMM;
    team.colActualTotals[month] = (team.colActualTotals[month] || 0) + item.ActualMM;
  }

  /** * @description 투입 공수 기반 가동률(Utilization) 계산 및 에러 스타일 판별
   * @returns {Object} 계산된 % 수치 및 스타일 클래스
   */
  calculateUtilization(contract, actual, capacity) {
    const cUtil = capacity > 0 ? Math.round((contract / capacity) * 100 * 10) / 10 : 0;
    const aUtil = capacity > 0 ? Math.round((actual / capacity) * 100 * 10) / 10 : 0;
    return {
      contract: contract.toFixed(1),
      actual: actual.toFixed(1),
      cUtil, aUtil,
      // 100% 가동률 초과 시 텍스트 빨간색 강조
      aUtilClass: (actual / capacity) > 1 ? 'slds-text-color_error' : ''
    };
  }

  /** @description 투입 수치별 Heatmap 배경색 클래스 결정 */
  getHeatmapClass(actual) {
    if (actual === 0) return 'status-none';     // 투입 없음 (투명/회색)
    if (actual < 0.3) return 'status-low';      // 저가동 (하늘색)
    if (actual <= 0.7) return 'status-normal';  // 적정 가동 (초록색)
    return 'status-over';                       // 과부하 (빨간색)
  }
}