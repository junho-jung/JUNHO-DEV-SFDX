/**
* @Author            : AI Assistant
* @Description       : SOAR 흐름 전반에서 공통으로 사용하는 경로 추적(Trace) 유틸리티.
*                      - 클래스/메서드 진입 시점을 일관된 포맷으로 System.debug에 남긴다.
*                      - context 맵을 함께 넘기면 JSON 형태로 직렬화하여 상세 정보를 기록한다.
*/
public with sharing class SecuritySoarTrace {

    private static final String PREFIX = '[SOAR_TRACE]';

    public static void log(String location) {
        System.debug(LoggingLevel.INFO, PREFIX + ' ' + location);
    }

    public static void log(String location, String jsonData) {
        System.debug(LoggingLevel.INFO, PREFIX + ' ' + location + jsonData);
    }

    public static void log(String location, Map<String, Object> context) {
        String ctx = (context == null || context.isEmpty())
            ? ''
            : ' ' + JSON.serialize(context);
        System.debug(LoggingLevel.INFO, PREFIX + ' ' + location + ctx);
    }
}