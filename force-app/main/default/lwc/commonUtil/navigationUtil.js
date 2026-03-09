/**
 * @Author            : jh.jung
 * @Description     :
 * @Target            :
 * @Modification Log
 Ver      Date            Author           Modification
 ===================================================================================
 1.0      2025-12-16      jh.jung           Created
 */

import { NavigationMixin } from "lightning/navigation";

/**
 * @author th.kim
 * @description 기본 Navigation Util
 * @param component 현재 컴포넌트
 * @param apiName 페이지의 apiName이나 개체의 apiName
 * @param actionName 개체 페이지 이동일 시 Action Type ('home', 'list', 'new')
 * @param recordId 레코드 페이지 이동 시 recordId
 * @param state 파라미터 값
 * @param url 외부 url
 * @param isNewWindow 새창 오픈 여부
 */
const defaultNavigation = (component, apiName, actionName, recordId, state, url, isNewWindow) => {

  // url 존재 시 url navigation 호출
  if (url) {
    externalNavigation(component, url);
  }
  // url x
  else {
    // recordId 존재 시 record navigation 호출
    if (recordId) {
      recordNavigation(component, apiName, recordId, state, isNewWindow);
    }
    // actionName 존재할 경우 object navigation
    else if (actionName) {
      objectNavigation(component, apiName, actionName, state, isNewWindow);
    }
    // actionName 존재하지 않을 경우 object navigation
    else {
      objectNavigation(component, apiName, "home", state, isNewWindow);
    }
  }
};

/**
 * @description 레코드 페이지 이동 Navigation
 */
const recordNavigation = (component, objectApiName, recordId, state, isNewWindow, isReplace) => {
  if (isNewWindow) {
    component[NavigationMixin.GenerateUrl]({
      type: "standard__recordPage",
      attributes: {
        recordId: recordId,
        objectApiName: objectApiName,
        actionName: "view"
      },
      state: state
    }, isReplace).then(url => {
      window.open(url);
    });
  } else {
    component[NavigationMixin.Navigate]({
      type: "standard__recordPage",
      attributes: {
        recordId: recordId,
        objectApiName: objectApiName,
        actionName: "view"
      },
      state: state
    }, isReplace);
  }
};

/**
 * @description 오브젝트 관련 Navigation
 */
const objectNavigation = (component, objectApiName, actionName, state, isNewWindow) => {
  if (isNewWindow) {
    component[NavigationMixin.GenerateUrl]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: objectApiName,
        actionName: actionName
      },
      state: state
    }).then(url => {
      window.open(url);
    });
  } else {
    component[NavigationMixin.Navigate]({
      type: "standard__objectPage",
      attributes: {
        objectApiName: objectApiName,
        actionName: actionName
      },
      state: state
    });
  }
};

/**
 * @description url Navigation
 */
const externalNavigation = (component, url) => {
  component[NavigationMixin.Navigate]({
    // type: "standard__webPage",
    type: "standard__webPage",
    attributes: {
      url: url
    }
  });
};

const componentNavigation = (component, componentName, state) => {
  component[NavigationMixin.Navigate]({
    type: 'standard__component',
    attributes: {
      componentName: componentName
    },
    state: state
  });
}

const navItemPageNavigation = (component, apiName, state) => {
  component[NavigationMixin.Navigate]({
    type: 'standard__navItemPage',
    attributes: {
      apiName: apiName
    },
    state: state
  });
}

export {
  defaultNavigation,
  recordNavigation,
  objectNavigation,
  externalNavigation,
  componentNavigation,
  navItemPageNavigation
};