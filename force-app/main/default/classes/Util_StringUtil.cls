/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public with sharing class Util_StringUtil {

    /**
    * @description NVL(값, NULL 반환값)
    * @param val1 original value
    * @param val2 value if original value is null
    *
    * @return String
    */
    public String nvl(String val1, String val2) {
        return val1 ?? val2;
    }

    /**
     * @description 숫자와 영어를 제외한 모든 문자 제거
     * @param str String
     *
     * @return String
     */
    public String filterAlphanumeric(String str){
        return String.isBlank(str) ? '' : str.replaceAll('[^a-zA-Z0-9]', '');
    }


    /**
     * @description 한국어 판별
     * @param str String
     *
     * @return Boolean
     */
    public Boolean isKorean(String str) {
        if (String.isBlank(str)) {
            return false;
        }
        // 한글 Unicode 범위: U+AC00 ~ U+D7A3
        // 정규 표현식을 사용하여 한글 여부 확인
        Pattern pattern = Pattern.compile('^[\\uAC00-\\uD7A3]+$');
        Matcher matcher = pattern.matcher(str);

        // 문자열이 한글로만 구성되어 있다면 true 반환
        return matcher.matches();
    }

    public Boolean isEmail(String email) {
        return String.isBlank(email) ? false : Pattern.matches('[a-zA-Z0-9]+[a-zA-Z0-9\\.\\_]*[a-zA-Z0-9]+@[a-zA-Z0-9\\-]+(\\.[a-zA-Z]+)+', email);
    }



}