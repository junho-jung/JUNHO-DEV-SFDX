/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-29      jh.jung           Created
*/
@IsTest
private class HttpCallOutOrgCache_test {
    @IsTest
    static void testBehavior() {
        final String key = 'test';

        Assert.isNotNull(HttpCallOutOrgCache.THRESHOLD_DURING_MINUTES);
        Assert.isNull(HttpCallOutOrgCache.get(key));
        HttpCallOutOrgCache.put(key, new Map<String, String>{'key' => 'value'}, 300);
        Assert.isNotNull(HttpCallOutOrgCache.get(key));
        HttpCallOutOrgCache.remove(key);
        HttpCallOutOrgCache.remove(key + 'error');

        HttpCallOutOrgCache.KakaoAuthInfo authInfo = new HttpCallOutOrgCache.KakaoAuthInfo(new Map<String, String>{
            HttpCallOutConsts.AUTH_ACCESS_TOKEN_KEY_NAME => '1234567890'
        });

        Assert.isNotNull(authInfo);
        Assert.isFalse(authInfo.isRefresh);
    }
}