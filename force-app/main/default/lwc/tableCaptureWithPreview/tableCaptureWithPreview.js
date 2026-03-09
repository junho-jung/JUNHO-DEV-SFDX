/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2026-01-28      jh.jung           Created
 */

import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class TableCaptureWithPreview extends LightningElement {
  @api recordId;
  @track pastedData = '';

  // 기본 스타일 상수 정의
  TABLE_STYLE = 'border-collapse:collapse; width:auto; table-layout:fixed; font-family:sans-serif; font-size:11px; border:1px solid #d4d4d4; background:#fff; min-width:max-content;';
  CELL_STYLE = 'border:1px solid #d4d4d4; padding:6px 10px; vertical-align:middle; word-break:break-all;';
  WRAPPER_STYLE = 'width:100%; overflow-x:auto; -webkit-overflow-scrolling:touch; margin-bottom:10px; border:1px solid #eee;';

  handleInputChange(event) {
    this.pastedData = event.target.value;
  }

  /**
   * Getter: 입력된 데이터에 스타일을 입혀 미리보기로 반환
   */
  get formattedPreview() {
    return this.pastedData ? this.applyFancyStyle(this.pastedData) : '';
  }

  /**
   * 메인 가공 함수: 엑셀 HTML을 클렌징하고 커스텀 스타일 주입
   */
  // applyFancyStyle(html) {
  //   if (!html) return '';
  //
  //   const parser = new DOMParser();
  //   const doc = parser.parseFromString(html, 'text/html');
  //   const table = doc.querySelector('table');
  //   if (!table) return html;
  //
  //   // 1. colgroup span 해제 및 너비 정보 추출
  //   const rawWidths = this.extractWidthsFromColgroup(table);
  //
  //   // 2. 데이터 정제: 빈 열 제거
  //   this.removeEmptyRowsAndCols(table, rawWidths);
  //
  //   // 3. 스타일 주입 및 최종 가공
  //   this.applyInlineStyles(table, rawWidths);
  //
  //   // 4. 가로 스크롤 가능한 래퍼로 감싸 반환
  //   return `<div class="table-scroll-wrapper" style="${this.WRAPPER_STYLE}">${table.outerHTML}</div>`;
  // }

  applyFancyStyle(html) {
    if (!html) return '';
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const table = doc.querySelector('table');
    if (!table) return html;

    // 1. 너비 정보 추출 및 평탄화
    const rawWidths = this.extractWidthsFromColgroup(table);

    // 2. 빈 행/열 제거
    this.removeEmptyRowsAndCols(table, rawWidths);

    // 3. [핵심] 반복되는 스타일을 CSS 클래스로 정의 (문자열 용량 최적화)
    const styleId = `t-${Math.random().toString(36).substr(2, 5)}`; // 고유 ID 생성
    const styleTag = `
    <style>
        .${styleId} { ${this.TABLE_STYLE} }
        .${styleId} td { ${this.CELL_STYLE} }
        .${styleId} .first-row td { border-top: 1px solid #d4d4d4; }
    </style>`.replace(/\s+/g, ' '); // CSS 내부 공백 압축

    // 4. 테이블에 클래스 부여 및 불필요 속성 대량 제거
    table.className = `ql-table-blob ${styleId}`;
    table.removeAttribute('width');
    table.removeAttribute('border');

    const rows = Array.from(table.querySelectorAll('tr'));
    rows.forEach((row, trIdx) => {
      row.removeAttribute('height');
      row.removeAttribute('style');

      if (trIdx === 0) row.classList.add('first-row');

      Array.from(row.cells).forEach((cell, tdIdx) => {
        // colspan/rowspan이 1인 경우 제거 (용량 줄이기)
        if (cell.colSpan === 1) cell.removeAttribute('colspan');
        if (cell.rowSpan === 1) cell.removeAttribute('rowspan');
        cell.removeAttribute('height');
        cell.removeAttribute('width');
        cell.removeAttribute('class'); // 엑셀 클래스(xl65 등) 제거

        // 기존 엑셀 스타일 보존이 필요한 경우에만 최소한으로 남김
        const originalCss = cell.style.cssText;
        cell.removeAttribute('style');

        // 첫 번째 행 너비 고정값만 인라인으로 남김 (나머지는 클래스로 처리)
        let inlineStyle = '';
        if (trIdx === 0 && rawWidths[tdIdx]) {
          const w = rawWidths[tdIdx];
          inlineStyle += `width:${w}pt;min-width:${w}pt;`;
        }
        if (originalCss) inlineStyle += originalCss.replace(/\s+/g, '');

        if (inlineStyle) cell.setAttribute('style', inlineStyle);
      });
    });

    // 5. 최종 결과물 압축 (태그 사이 공백 제거)
    const finalHtml = (styleTag + table.outerHTML).replace(/>\s+</g, '><');

    return `<div class="table-scroll-wrapper" style="${this.WRAPPER_STYLE}">${finalHtml}</div>`;
  }

  /**
   * [Helper] colgroup의 span 속성을 해석하여 평탄화된 너비 배열 반환
   */
  extractWidthsFromColgroup(table) {
    const widths = [];
    const colGroup = table.querySelector('colgroup');
    if (!colGroup) return widths;

    Array.from(colGroup.querySelectorAll('col')).forEach(col => {
      const span = parseInt(col.getAttribute('span') || '1', 10);
      const width = col.getAttribute('width');
      for (let s = 0; s < span; s++) {
        widths.push(width);
      }
    });
    colGroup.remove(); // 가공 후 제거
    return widths;
  }

  /**
   * [Helper] 전체가 비어있는 열(TD)을 제거
   */
  removeEmptyRowsAndCols(table, rawWidths) {

    // 열(Column) 처리: 다시 갱신된 행 기준으로 빈 열 삭제
    const updatedRows = Array.from(table.querySelectorAll('tr'));
    if (updatedRows.length === 0) return;

    const colCount = updatedRows[0].cells.length;
    // 뒤에서부터 순회해야 인덱스 변경 영향이 없음
    for (let i = colCount - 1; i >= 0; i--) {
      const isColEmpty = updatedRows.every(row => {
        const cell = row.cells[i];
        return cell ? !cell.textContent.trim() : true;
      });

      if (isColEmpty) {
        updatedRows.forEach(row => { if (row.cells[i]) row.deleteCell(i); });
        if (rawWidths.length > 0) rawWidths.splice(i, 1);
      }
    }
  }

  /**
   * [Helper] 각 셀에 인라인 스타일 및 너비 정보 주입
   */
  applyInlineStyles(table, rawWidths) {
    table.setAttribute('style', this.TABLE_STYLE);
    table.classList.add('ql-table-blob');

    const rows = table.querySelectorAll('tr');
    rows.forEach((row, trIdx) => {
      Array.from(row.cells).forEach((cell, tdIdx) => {
        const originalStyle = cell.style.cssText; // 기존 배경색 등 보존
        let finalStyle = this.CELL_STYLE;

        // 첫 번째 행에서 열 너비 고정
        if (trIdx === 0 && rawWidths[tdIdx]) {
          const w = rawWidths[tdIdx];
          finalStyle += `width:${w}pt; min-width:${w}pt;`;
        }

        cell.setAttribute('style', `${finalStyle} ${originalStyle}`);
      });
    });
  }

  /**
   * 스타일이 적용된 HTML을 클립보드에 복사
   */
  async handleCopy() {
    if (!this.formattedPreview) return;

    try {
      const type = "text/html";
      const blob = new Blob([this.formattedPreview], { type });
      const data = [new ClipboardItem({ [type]: blob })];

      await navigator.clipboard.write(data);
      this.showToast('복사 완료', '스타일이 적용된 표가 복사되었습니다.', 'success');
    } catch (error) {
      console.error(error);
      this.showToast('복사 실패', '브라우저 보안 설정으로 복사할 수 없습니다.', 'error');
    }
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  handleCancel() {
    this.pastedData = '';
    this.dispatchEvent(new CloseActionScreenEvent());
  }
}