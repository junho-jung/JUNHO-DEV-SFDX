/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2025-12-16      jh.jung           Created
 */

import { LightningElement, track } from "lwc";

// Library
import formFactor from '@salesforce/client/formFactor';

// Util
import { labelList } from "c/commonUtil";

import getLeadListByFilter from "@salesforce/apex/KakaoMapController.getLeadListByFilter";


export default class leadMap extends LightningElement {

  vfHost = labelList.VFHost;
  markerFilterValue = '15';

  markerFilterOptions = [
    {label: '15일 이내', value: '15'},
    {label: '15일 ~ 30일', value: '30'},
    {label: '30일 ~ 60일', value: '60'},
    {label: '60일 이후', value: '999'}
  ];


  connectedCallback() {
    // vf에서 받아올 이벤트 생성
    window.addEventListener("message", this.getDataFromChild.bind(this));
  }

  /**
   * @description iframe 로드 시 리드 데이터 vf에 넘겨주기
   */
  handleLoad() {
    console.log('handleLoad start');
    console.log('this.vfHost ::: ' + this.vfHost);
    console.log('origin ::: ' + window.location.origin);
    getLeadListByFilter({num : this.markerFilterValue}).then(res => {
      // this.res.forEach(lead => {
      // 	lead.url = '/lightning/r/Lead/' + lead.Id + '/view';
      // });
      const iframe = this.template.querySelector("iframe");
      if (iframe) {
        const contentWindow = iframe.contentWindow;
        const data = {target: "kakaoMap", formFactor: formFactor, leadList: res};
        contentWindow.postMessage(data, this.vfHost);
      }
    }).catch(err => {
      console.log("err :: ", err.message);
    });
  }

  /**
   * @description vf 맵에서 리드 마커 클릭 시 부모 컴포넌트로 이벤트 전송
   * @param e 클릭한 데이터 이벤트
   */
  getDataFromChild(e) {
    if (this.vfHost !== e.origin || e.data.target !== "kakaoMap") return;

    const customEvent = new CustomEvent('markerclick', {
      detail: {data: e.data}
    });
    this.dispatchEvent(customEvent);
  }

  // 필터 변경되면 data 바꿔서 맵 로딩 다시
  handleFilterChange(e) {
    this.markerFilterValue = e.detail.value;

    // const iframe = this.template.querySelector('iframe');
    // const baseUrl = "/apex/KakaoMap?isdtp=p1";
    // const uniqueParam = `timestamp=${new Date().getTime()}`; // 항상 다른 값을 추가
    //
    // iframe.src = `${baseUrl}&${uniqueParam}`;

    // 아이폰에서는 위 방식으론 안되서 변경
    const iframe = this.template.querySelector('iframe');
    if (iframe) {
      this.handleLoad();
    }

    const customEvent = new CustomEvent('markerfilter', {
      detail: {data: e.detail.value}
    });
    this.dispatchEvent(customEvent);
  }
}