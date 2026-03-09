/**
* @Author            : jh.jung
* @Description 		 : Cache로 Token값 관리
* @Target            : 만트럭 HttpCallOutConsts 참조
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-29      jh.jung           Created
*/
public without sharing class HttpCallOutConsts {
    //-----------------------------------------------------------
    // 기본 Header 세팅
    //-----------------------------------------------------------
    public static final String KAKAO_AUTH_INFO_KEY;
    public static final String CACHE_PARTITION_NAME;
    public static final Integer TIMEOUT;
    public static final Set<Integer> SUCCESS_CODES;
    public static final Set<Integer> UNAUTHORIZED_CODES;
    public static final String SYSTEM_ERROR_CODE;
    public static final String AUTH_ACCESS_TOKEN_KEY_NAME;

    public static Integer auth_retry_count = 3; // 기본 재실행 횟수
    public static Integer auth_retry_sleep = 1000; // 기본 재실행 sleep 시간(ms)
    public static Integer auth_info_org_cache_tts = 40*60; // 인증 정보 org partition cache expired time (초) : 분*60
    public static Boolean isCheckEnv = true;
    public static String kakao_base_url;

    static {
        KAKAO_AUTH_INFO_KEY = 'KakaoAuthInfo';
        CACHE_PARTITION_NAME = 'KakaoCallOutPartition';
        TIMEOUT = 12000;
        SYSTEM_ERROR_CODE = '999';
        AUTH_ACCESS_TOKEN_KEY_NAME = 'refresh_token';

        SUCCESS_CODES = new Set<Integer>{200, 201, 302};
        UNAUTHORIZED_CODES = new Set<Integer>{401};

        //-----------------------------------------------------------
        // 기본값 지정 필드의 custom meta 에서 조정 가능 수행
        // 에러 발생시 무시
        //-----------------------------------------------------------
        try {
//            auth_retry_count = Integer.valueOf(APIM_CALLOUT__mdt.getInstance('auth_retry_count').value__c);
//            auth_retry_sleep = Integer.valueOf(APIM_CALLOUT__mdt.getInstance('auth_retry_sleep').value__c);
//            auth_info_org_cache_tts = Integer.valueOf(APIM_CALLOUT__mdt.getInstance('auth_info_org_cache_tts').value__c)*60;
//            isCheckEnv = APIM_CALLOUT__mdt.getInstance('isCheckEnv').value__c.toUpperCase() == 'Y' ? true : false;
//            kakao_base_url = APIM_CALLOUT__mdt.getInstance('apim_domain').value__c + APIM_CALLOUT__mdt.getInstance('apim_path').value__c;
        } catch (Exception e){}
    }

}