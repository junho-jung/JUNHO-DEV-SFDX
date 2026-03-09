/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class Util_EncodingUtil {

    /**
     * @description URL Encode
     * @param str String
     *
     * @return String
     */
    public String urlEncode(String str) {
        return String.isBlank(str) ? null : EncodingUtil.urlEncode(str, 'UTF-8');
    }

    /**
     * @description 암호화 - SHA1 등등
     * @param method 암호화 방법
     * @param key Key
     *
     * @return String
     */
    public String convertToHex(String method, String key) {
        return EncodingUtil.convertToHex(Crypto.generateDigest(method, Blob.valueOf(key)));
    }
}