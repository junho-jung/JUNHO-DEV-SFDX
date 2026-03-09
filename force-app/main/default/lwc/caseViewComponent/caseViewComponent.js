/*************************************************************
 * @author : jh.jung
 * @date : 2024-08-05
 * @description :
 * @target :
 ==============================================================
 * Ver          Date            Author          Modification
 * 1.0          2024-08-05      jh.jung         Initial Version
 **************************************************************/
import {api, track, LightningElement} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {} from 'lightning/empApi';

import initCaseInfo from "@salesforce/apex/CaseViewHandlerController.initCaseInfo";
import initRadioInfo from "@salesforce/apex/CaseViewHandlerController.initRadioInfo";
import doSaveRadio from "@salesforce/apex/CaseViewHandlerController.doSaveRadio";

export default class CaseViewComponent extends NavigationMixin(LightningElement) {
  @api recordId;
  accountName = "";
  ownerName = "";
  model = "";
  installationDate;
  sn = "";
  warranty = "";
  userCreatedDate;
  userClosedDate;
  others = "";
  description = [];
  contactName = "";
  contactTitle = "";
  contactDepartment = "";
  @track resultList = [];
  isFirst;

  connectedCallback() {
    console.log('inner connectedCallback');
    console.log(this.recordId);
    this.isFirst = true;

    initCaseInfo({recordId : this.recordId})
      .then(res => {
        this.accountName = res.Account.Name;
        this.ownerName = res.Owner.Name;
        this.model = (res.Model__c != undefined) ? res.Model__c : "";
        this.installationDate = res.InstallationDate__c;
        this.sn = (res.SN__c != undefined) ? res.SN__c : "";
        this.warranty = (res.Warranty__c != undefined) ? res.Warranty__c : "";
        this.userCreatedDate = (res.UserCreateDate__c != null) ? res.UserCreateDate__c : null;
        this.userClosedDate = (res.UserCloseDate__c != null) ? res.UserCloseDate__c : null;
        this.others = res.Others__c;
        this.description = res.Description.split('\n');
        this.contactName = res.Contact.Name;
        this.contactTitle = res.Contact.Title;
        this.contactDepartment = res.Contact.Department;
      })
      .catch(err => {
        console.log(err);
      });

    initRadioInfo({recordId : this.recordId})
      .then(res => {
        this.resultList = res;
        console.log('this.resultList ::: ' + this.resultList);
      })
      .catch(err => {
        console.log(err);
      });
  }

  doSave() {
    console.log('this.resultList ::: ' + this.resultList);
    // result값만 가져와서 저장
    doSaveRadio({recordId : this.recordId, radioList : this.resultList})
      .then(res => {
        console.log(res);
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Success',
            message: 'Result 값이 저장되었습니다.',
            variant: 'success',
          })
        );
      })
      .catch(err =>{
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: '관리자에게 문의해주세요.',
            variant: 'error',
          })
        );
      })
  }

  editCurrentRecord() {
    this[NavigationMixin.Navigate]({
      type: 'standard__recordPage',
      attributes: {
        recordId: this.recordId,
        objectApiName: 'Case',
        actionName: 'edit'
      },
    });
  }

  changeRadio(e) {
    this.resultList[e.target.name] = e.target.value;
  }

  get itemsWithIndexZero() {
    console.log('itemsWithIndexZero ::: this.resultList ::: ' + this.resultList)
    return this.description.map((item, index) => ({
      item,
      id: index,
      isIndexZero: index === 0,
      radio: this.resultList[index] == 1
    }));
  }
}