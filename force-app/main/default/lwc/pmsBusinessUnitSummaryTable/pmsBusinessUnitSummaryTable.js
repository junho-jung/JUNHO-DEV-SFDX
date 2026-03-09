/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-20      jh.jung           Created
 1.1      2026-01-27      jh.jung           Refactoring / Commenting
 */
import { LightningElement, api, track } from 'lwc';

/**
 * @description 비즈니스 유닛(BU) 산하 팀들의 가동률 요약 정보를 제공하는 컴포넌트
 */
export default class PmsBusinessUnitSummaryTable extends LightningElement {
  // -------------------------------------------------------------------------
  // [1] Properties & State: 데이터 정의 및 캐싱
  // -------------------------------------------------------------------------

  _allocations = [];
  _processedData = null; // 성능 최적화를 위한 계산 결과 캐시

  @api
  get allocationsData() { return this._allocations; }
  /** @description 데이터가 변경되면 자동으로 캐시를 비워 재계산을 유도함 */
  set allocationsData(value) {
    this._allocations = value || [];
    this._processedData = null;
  }

  @api currentHalf;  // 상/하반기 구분
  @api headerLabel;  // 테이블 제목

  @track isExpanded = false; // 테이블 본문 펼침/닫힘 상태

  // -------------------------------------------------------------------------
  // [2] Getters: UI 표현 제어
  // -------------------------------------------------------------------------

  get monthNums() {
    return this.currentHalf === 'H1' ? [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] : [1, 2, 3, 4, 5, 6];
  }

  get monthLabels() {
    return this.monthNums.map(m => `${m}월`);
  }

  get toggleIcon() {
    return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
  }

  get tbodyClass() {
    return this.isExpanded ? 'animate-fade-in' : 'slds-hide';
  }

  /** * @description [핵심 관제탑] 가공된 데이터를 반환.
   * 캐시가 있으면 즉시 반환하여 불필요한 연산을 방지 (Memoization)
   */
  get processedData() {
    if (this._processedData) return this._processedData;
    if (!this._allocations?.length) return null;

    // 1. 기초 데이터 그룹화 (팀별/전체별 합계 맵 생성)
    const { teamMap, totalRaw } = this.groupAllocationsByTeam();

    // 2. 맵핑된 기초 데이터를 기반으로 UI용 통계 모델 생성
    this._processedData = {
      teams: Object.values(teamMap).map(team => this.formatStatisticalRow(team)),
      total: this.formatStatisticalRow(totalRaw)
    };

    return this._processedData;
  }

  // -------------------------------------------------------------------------
  // [3] Private Methods: 데이터 처리 로직 분리
  // -------------------------------------------------------------------------

  /** * @description 원본 배열을 순회하며 팀별/전체별 M/M 수치를 합산
   * @returns {Object} { teamMap, totalRaw }
   */
  groupAllocationsByTeam() {
    const teamMap = {};
    const totalRaw = this.initializeRowData('전체 합계');

    this._allocations.forEach(item => {
      const month = item.Month;
      if (!this.monthNums.includes(month)) return;

      // 팀 데이터 초기화
      if (!teamMap[item.TeamId]) {
        teamMap[item.TeamId] = this.initializeRowData(item.TeamName, item.TeamId);
      }

      const team = teamMap[item.TeamId];

      // 수치 누적 (팀 및 전체 합계 동시 처리)
      this.accumulateMM(team, item, month);
      this.accumulateMM(totalRaw, item, month);
    });

    return { teamMap, totalRaw };
  }

  /** * @description 누적된 기초 데이터를 바탕으로 가동률(%) 및 포맷팅 수행
   * @param {Object} data 맵핑된 기초 로우 데이터
   * @returns {Object} UI용 포맷팅 데이터
   */
  formatStatisticalRow(data) {
    const memberCount = data.memberIds.size;
    const monthCount = this.monthNums.length;
    const totalCapacity = memberCount * monthCount; // 가용 총 M/M

    // 전체 기간 계약/실제 합계
    const grandC = Object.values(data.colC).reduce((a, b) => a + b, 0);
    const grandA = Object.values(data.colA).reduce((a, b) => a + b, 0);

    return {
      ...data,
      memberCount,
      totalCapacity,
      // 월별 상세 통계
      monthly: this.monthNums.map(m => {
        const c = data.colC[m] || 0;
        const a = data.colA[m] || 0;
        return this.calculateMonthlyUtilization(c, a, memberCount, m);
      }),
      // 우측 끝 전체 총계 열
      grandTotal: this.calculateGrandUtilization(grandC, grandA, totalCapacity)
    };
  }

  // -------------------------------------------------------------------------
  // [4] Helper Methods: 재사용 유틸리티
  // -------------------------------------------------------------------------

  /** @description 데이터 로우(팀/전체) 초기 구조 생성 */
  initializeRowData(name, id = null) {
    return {
      id, name,
      memberIds: new Set(),
      colC: {}, // Month별 ContractMM 합계
      colA: {}  // Month별 ActualMM 합계
    };
  }

  /** @description M/M 합산 및 인원수 카운트 */
  accumulateMM(target, item, month) {
    target.memberIds.add(item.MemberId);
    target.colC[month] = (target.colC[month] || 0) + (item.ContractMM || 0);
    target.colA[month] = (target.colA[month] || 0) + (item.ActualMM || 0);
  }

  /** @description 월별 가동률 계산 및 스타일 클래스 할당 */
  calculateMonthlyUtilization(c, a, memberCount, month) {
    const cUtil = memberCount > 0 ? Math.round((c / memberCount) * 100 * 10) / 10 : 0;
    const aUtil = memberCount > 0 ? Math.round((a / memberCount) * 100 * 10) / 10 : 0;
    return {
      month,
      c: c.toFixed(1),
      a: a.toFixed(1),
      cUtil,
      aUtil,
      // 100% 초과 시 빨간색 강조
      cUtilClass: cUtil > 100 ? 'slds-text-color_error slds-text-title_bold' : 'util-bold',
      aUtilClass: aUtil > 100 ? 'slds-text-color_error slds-text-title_bold' : 'util-bold',
    };
  }

  /** @description 행 전체 가동률(Grand Total) 계산 */
  calculateGrandUtilization(grandC, grandA, totalCapacity) {
    const cUtil = totalCapacity > 0 ? Math.round((grandC / totalCapacity) * 100 * 10) / 10 : 0;
    const aUtil = totalCapacity > 0 ? Math.round((grandA / totalCapacity) * 100 * 10) / 10 : 0;
    return {
      c: grandC.toFixed(1),
      a: grandA.toFixed(1),
      cUtil,
      aUtil,
      cUtilClass: cUtil > 100 ? 'slds-text-color_error' : '',
      aUtilClass: aUtil > 100 ? 'slds-text-color_error' : '',
    };
  }

  handleToggle() {
    this.isExpanded = !this.isExpanded;
  }
}