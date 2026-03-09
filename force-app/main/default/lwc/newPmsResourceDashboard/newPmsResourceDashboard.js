/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2025-12-29      jh.jung           Created
 */

import { LightningElement, track } from 'lwc';
import getAllocations from '@salesforce/apex/New_PMS_ResourceManagementController.getAllocations';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class NewPmsResourceDashboard extends LightningElement {
  @track viewMode = 'team';
  @track projectMode = 'read'; // read or edit
  @track originalData = [];
  @track draftValues = {};
  @track isLoading = false;
  @track selectedProjectIds = [];

  selectedYear = '2025';
  selectedDivision = 'D_Solution';
  selectedTeam = 'T_SF1';
  selectedHalf = 'H1';

  // 옵션 설정
  yearOptions = [
    { label: '2025년', value: '2025' },
    { label: '2026년', value: '2026' },
  ];
  halfOptions = [
    { label: '상반기', value: 'H1' },
    { label: '하반기', value: 'H2' }
  ];
  divisionOptions = [
    { label: '솔루션사업부', value: 'D_Solution' },
  ];
  teamOptions = [
    { label: 'SF1팀', value: 'T_SF1' },
    { label: 'SF2팀', value: 'T_SF2' },
    { label: '솔루션사업팀', value: 'T_SS' },
    { label: 'AX솔루션팀', value: 'T_AX' }
  ];
  rawProjectOptions = [
    { label: '만트럭', value: 'P01' },
    { label: '코오롱', value: 'P02' },
    { label: '포스코', value: 'P03' },
    { label: '클래시스', value: 'P04' },

    { label: '현대자동차', value: 'P05' },
    { label: '기아자동차', value: 'P06' },
    { label: '커넥스 구축', value: 'P07' },
    { label: '커넥스 운영', value: 'P08' },

    { label: '데이터 이쿠', value: 'P09' },
    { label: '태블로', value: 'P10' },
    { label: 'LLM', value: 'P11' },
  ];

  get isTeamView()      { return this.viewMode === 'team'; }
  get isProjectView()   { return this.viewMode === 'project'; }
  get isReadOnlyMode()  { return this.projectMode === 'read'; }
  get showEditActions()         { return this.isProjectView && this.projectMode === 'edit'; }
  get viewModeVariant()   { return this.projectMode === 'read' ? 'brand' : 'neutral'; }
  get editModeVariant()   { return this.projectMode === 'edit' ? 'brand' : 'neutral'; }

  // get cappedProgress()              { return Math.min(this.totalUtilization, 100); }
  // get cappedProgressStyle()   { return `width:${this.cappedProgress}%;`; }
  // get hasOverflow()         { return this.totalUtilization > 100; }
  // get overflowPercent()             { return this.totalUtilization - 100; }

  get projectLabel() {
    return this.selectedProjectIds.length > 0 ? `프로젝트 (${this.selectedProjectIds.length})` : '프로젝트 선택';
  }

  get projectOptions() {
    return this.rawProjectOptions.map(opt => ({
      ...opt,
      checked: this.selectedProjectIds.includes(opt.value)
    }));
  }

  get totalUtilization() {
    if (!this.isTeamView || this.originalData.length === 0) return 0;
    const actual = this.originalData.reduce((sum, i) => sum + i.ActualMM, 0);
    const members = new Set(this.originalData.map(i => i.MemberId)).size;
    return Math.round((actual / (members * 12)) * 100);
  }

  get totalProgressStyle() {
    return `width: ${this.totalUtilization}%; background: ${this.totalUtilization > 100 ? '#ea001e' : '#0070d2'}`;
  }

  connectedCallback() {
    this.initDefaultProject(); // 기본 프로젝트 설정 함수 호출
    this.fetchData();
  }

  initDefaultProject() {
    if (this.rawProjectOptions && this.rawProjectOptions.length > 0) {
      // 선택된 프로젝트가 없을 때만 첫 번째 항목을 추가
      if (this.selectedProjectIds.length === 0) {
        this.selectedProjectIds = [this.rawProjectOptions[0].value];
      }
    }
  }

  handleTabActive(event) {
    this.viewMode = event.target.value;
    this.projectMode = 'read';
    this.originalData = [];

    if (this.isProjectView && this.selectedProjectIds.length === 0) {
      this.initDefaultProject();
    }

    this.fetchData();
  }

  handleFilterChange(event) {
    const name = event.target.dataset.name;
    const value = event.detail.value;
    // this[name === 'year' ? 'selectedYear' : name === 'half' ? 'selectedHalf' : 'selectedTeam'] = value;
    this[
      name === 'year' ? 'selectedYear'
        : name === 'division' ? 'selectedDivision'
          : name === 'team' ? 'selectedTeam' :
            'selectedHalf'
      ] = value;
    if (name !== 'half') this.fetchData();
  }

  handleProjectSelect(event) {
    const val = event.detail.value;
    const idx = this.selectedProjectIds.indexOf(val);
    if (idx > -1) this.selectedProjectIds.splice(idx, 1);
    else this.selectedProjectIds.push(val);
    this.selectedProjectIds = [...this.selectedProjectIds];
    this.fetchData();
  }

  handleModeChange(event) {
    this.projectMode = event.target.dataset.mode;
    if (this.projectMode === 'read') this.draftValues = {};
  }

  async fetchData() {
    if (this.isProjectView && this.selectedProjectIds.length === 0) {
      this.originalData = []; return;
    }
    this.isLoading = true;
    try {
      this.originalData = await getAllocations({
        viewMode: this.viewMode,
        teamId: this.isTeamView ? this.selectedTeam : '',
        projectIds: this.isProjectView ? this.selectedProjectIds : [],
        year: this.selectedYear
      });
    } catch (e) {
      console.error(e);
    } finally {
      console.log('fetchData.length ::: ' + this.originalData.length)
      console.log('fetchData[0] ::: ' + JSON.stringify(this.originalData[0]))
      this.isLoading = false;
    }
  }

  handleGridAction(event) {
    this.draftValues = { ...this.draftValues, [event.detail.draftKey]: event.detail.value };
  }

  handleSave() {
    console.log('draftValues ::: ' + JSON.stringify(this.draftValues))
    this.showToast('성공', '공수가 저장되었습니다.', 'success');
    this.projectMode = 'read';
    this.draftValues = {};
    this.fetchData();
  }

  handleCancel() { this.draftValues = {}; this.projectMode = 'read'; }

  showToast(t, m, v) { this.dispatchEvent(new ShowToastEvent({ title: t, message: m, variant: v })); }
}