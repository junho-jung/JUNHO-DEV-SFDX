/*************************************************************
 * @author : jh.jung
 * @date : 2024-08-02
 * @description :
 * @target :
 ==============================================================
 * Ver          Date            Author          Modification
 * 1.0          2024-08-02      jh.jung         Initial Version
 **************************************************************/
import {LightningElement, api} from 'lwc';
import initCaseInfo from "@salesforce/apex/CaseViewHandlerController.initCaseInfo";
import doSaveCase from "@salesforce/apex/CaseViewHandlerController.doSaveCase";

export default class CaseViewHandler extends LightningElement {

  @api recordId;
  isModal;
  accountName;
  ownerName;
  model;
  installationDate;
  sn;
  warranty;
  createdDate;
  closedDate;
  others;
  consoleInspectionContent = [];

  @api invoke() {
    console.log('inner invoke');
    console.log(this.recordId);
    this.isModal = true;
    this.isFirst = true;

    initCaseInfo({recordId : this.recordId})
      .then(res => {
        // Account.Name, Owner.Name, Model__c, InstallationDate__c, SN__c, Warranty__c, CreatedDate, ClosedDate, Others__c, ConsoleInspectionContent__c
        this.accountName = res.Account.Name;
        this.ownerName = res.Owner.Name;
        this.model = res.Model__c;
        this.installationDate = res.InstallationDate__c;
        this.sn = res.SN__c;
        this.warranty = res.Warranty__c;
        this.createdDate = (res.CreatedDate != null) ? new Date(res.CreatedDate).toISOString().slice(0, 10) : null;
        this.closedDate = (res.ClosedDate != null) ? new Date(res.ClosedDate).toISOString().slice(0, 10) : null;
        this.others = res.Others__c;
        this.consoleInspectionContent = res.ConsoleInspectionContent__c.split('\n');
      })
      .catch(err => {
        console.log(err);
      });
  }

  closeModal() {
    this.isModal = false;
  }

  handleInputChange(e) {
    const field = e.target.name;
    const value = e.target.value;
    console.log('field ::: ' + field)
    console.log('value ::: ' + value)
    if(field == 'model')            this.model = value;
    if(field == 'sn')               this.sn = value;
    if(field == 'warranty')         this.warranty = value;
    if(field == 'others')           this.others = value;
  }

  handleInputListChange(e) {
    // items 배열의 해당 인덱스의 값을 업데이트
    const itemId = e.target.name;
    const value = e.target.value;
    this.consoleInspectionContent[itemId] = value;
    console.log('this.consoleInspectionContent[itemId] ::: ' + this.consoleInspectionContent[itemId])
  }

  doSave() {
    console.log('caseViewHandler')
    if(1 > this.warranty || this.warranty > 5 ) {
      console.log(this.warranty)
      return;
    }
    doSaveCase({recordId : this.recordId, model: this.model, sn: this.sn, warranty: this.warranty, consoleInspectionContent: this.consoleInspectionContent, others: this.others})
      .then(res => {
        console.log(res);
        setTimeout(() =>{
          location.reload();
        }, 1000);
        this.isModal = false;
      })
  }


  get itemsWithIndexZero() {
    return this.consoleInspectionContent.map((item, index) => ({
      item,
      id: index,
      isIndexZero: index === 0
    }));
  }
}