/**
* @Author            : jh.jung
* @Description 		 : Cache로 Token값 관리
* @Target            : 만트럭 HttpCallOutOrgCache 참조
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-29      jh.jung           Created
*/
public without sharing class HttpCallOutOrgCache {
    //-----------------------------------------------------------
    // 분단위 : Refresh Auth 임계치 분(Minute)
    // 기본은 40이지만 custom meta 의 설정에 준함
    //-----------------------------------------------------------
    @TestVisible
    private static Integer THRESHOLD_DURING_MINUTES = 40;

    static {
        //-----------------------------------------------------------
        // 기본 90분으로 설정하고 custom meta 세팅 정보를 최종으로 설정함.
        // 에러가 난 경우에는 무시하고 기본값으로 실행
        //-----------------------------------------------------------
        try {
            // THRESHOLD_DURING_MINUTES = Integer.valueOf(APIM_CALLOUT__mdt.getInstance('threshold_during_minutes').value__c);
        } catch (Exception e) { }
    }

    /**
     * org cache get
     * @param key
     * @return Object
     */
    public static Object get(String key) {
        Cache.OrgPartition partition = Cache.Org.getPartition(HttpCallOutConsts.CACHE_PARTITION_NAME);
        if (partition.contains(key)) {
            Object value = partition.get(key);
            if (value != null) {
                System.debug(LoggingLevel.INFO, String.format('>>> {0} has Data. ', new List<String>{key}));
            }
            return value;
        }
        return null;
    }

    /**
     * org cache put
     * @param key
     * @param value
     * @param ttl
     */
    public static void put(String key, Object value, Integer ttl) {
        Cache.OrgPartition partition = Cache.Org.getPartition(HttpCallOutConsts.CACHE_PARTITION_NAME);
        partition.put(key, value, ttl);
        System.debug(LoggingLevel.INFO, String.format('>>> {0} has been put', new List<String>{key}));
    }

    /**
     * org cache remove
     * @param key
     * @return boolean
     */
    public static Boolean remove(String key) {
        Cache.OrgPartition partition = Cache.Org.getPartition(HttpCallOutConsts.CACHE_PARTITION_NAME);
        Boolean removed = partition.remove(key);
        if (removed) {
            System.debug(LoggingLevel.INFO, String.format('>>> {0} has been removed', new List<String>{key}));
            return true;
        } else {
            return false;
        }
    }

    /**
     * Auth 인증 정보
     */
    public class KakaoAuthInfo {
        public Datetime cachedDatetime;
        public Boolean isRefresh {
            get {
                final Datetime currentDt = Datetime.now();
                final Long dt1 = currentDt.getTime();
                final Long dt2 = this.cachedDatetime.getTime();
                Long milliseconds = dt1 - dt2;
                Long seconds = milliseconds / 1000;
                Long minutes = seconds / 60;

                System.debug(System.LoggingLevel.INFO, '>>> minutes : ' + minutes);
                return (minutes > THRESHOLD_DURING_MINUTES);
            }
        }
        public Map<String, Object> authInfo;
        public String refreshToken;

        public KakaoAuthInfo(Map<String, Object> authInfo) {
            this.authInfo = authInfo;
            this.refreshToken = String.valueOf(this.authInfo.get(HttpCallOutConsts.AUTH_ACCESS_TOKEN_KEY_NAME));
            this.cachedDatetime = Datetime.now();
        }
    }

}