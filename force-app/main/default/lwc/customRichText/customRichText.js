import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFieldLabel from "@salesforce/apex/CustomRichTextController.getFieldLabel";
import saveRichText from "@salesforce/apex/CustomRichTextController.saveRichText";
export default class CustomRichText extends LightningElement {
  @api objectApiName;
  @api fieldApiName;
  @api recordId;
  @api sectionLabel;
  @api isOpen = false;
  @api hideSaveButton = false;
  isHideSection = false;
  fieldLabel = '';
  vfReady = false;
  _messageHandler = null;
  showModal = false;

  get modalContainerClass() {
    return this.showModal ? 'slds-modal slds-fade-in-open slds-modal_large modal-custom-large' : '';
  }
  get modalInnerClass() {
    return this.showModal ? 'slds-modal__container' : '';
  }
  get modalContentClass() {
    return this.showModal ? 'slds-modal__content slds-p-around_medium' : '';
  }
  get editorWrapClass() {
    return this.showModal ? 'modal-editor-wrap' : '';
  }
  get iframeClass() {
    return this.showModal ? 'vfFrame vfFrameModal' : 'vfFrame';
  }

  get sectionClass() {
    return this.isOpen ? "slds-section slds-is-open" : "slds-section";
  }

  toggle() {
    this.isOpen = !this.isOpen;
  }
  get _isOpen() {
    return this.isOpen;
  }

  @api
  save() {
    this.handleSave();
  }

  get _vfBaseUrl() {
    if (!this.vfReady) return '';
    return '/apex/customRichText'
      + '?id=' + encodeURIComponent(this.recordId)
      + '&objectName=' + encodeURIComponent(this.objectApiName)
      + '&fieldName=' + encodeURIComponent(this.fieldApiName);
  }

  get vfUrl() {
    if (!this._vfBaseUrl) return '';
    return this._vfBaseUrl;
  }

  connectedCallback() {
    if (this.objectApiName != null && this.fieldApiName != null) {
      this.setLabel();
      this.vfReady = true;
    }
    // postMessage 수신 핸들러 등록
    this._messageHandler = (event) => {
      const data = event.data;
      if (!data || typeof data !== 'object') return;
      if (data.type === 'RESPONSE_EDITOR_HTML' && data.requestId === this._pendingRequestId) {
        this._pendingRequestId = null;
        this._doSaveApex(data.html);
      }
    };
    window.addEventListener('message', this._messageHandler);
  }

  renderedCallback() {
    if (this.objectApiName != null && this.fieldApiName != null) {
      this.vfReady = true;
      this.isHideSection = this.sectionLabel != null ? false : true;
    }
  }

  setLabel() {
    getFieldLabel({
      objectApiName: this.objectApiName,
      fieldApiName: this.fieldApiName
    }).then((result) => {
      this.fieldLabel = result;
    }).catch(error => {

    }).finally(() => {

    });
  }


  disconnectedCallback() {
    if (this._messageHandler) {
      window.removeEventListener('message', this._messageHandler);
    }
  }

  openModal() {
    this.showModal = true;
  }

  closeModal() {
    this.showModal = false;
  }

  // =========================================================
  // 저장: postMessage → iframe에서 HTML 수신 → Apex 저장
  // =========================================================
  handleSave() {
    const iframe = this.template.querySelector('iframe.vfFrame');
    if (!iframe || !iframe.contentWindow) {
      this._showToast('에디터가 아직 로드되지 않았습니다.', 'error');
      return;
    }
    this._pendingRequestId = 'req_' + Date.now();
    iframe.contentWindow.postMessage(
      { type: 'REQUEST_EDITOR_HTML', requestId: this._pendingRequestId },
      '*'
    );
  }

  _doSaveApex(html) {
    saveRichText({
      recordId: this.recordId,
      objectApiName: this.objectApiName,
      fieldApiName: this.fieldApiName,
      htmlContent: html
    })
      .then((result) => {
        const isError = /^ERROR\s*:/i.test(result || '');
        const msg = (result || '').replace(/^(OK|ERROR)\s*:\s*/i, '') || '저장 완료';
        this._showToast(msg, isError ? 'error' : 'success');
        if (!isError && this.showModal) {
          this.showModal = false;
        }
      })
      .catch((error) => {
        this._showToast(error.body ? error.body.message : '저장 실패', 'error');
      });
  }

  _showToast(message, variant) {
    this.dispatchEvent(new ShowToastEvent({ message, variant }));
  }

}