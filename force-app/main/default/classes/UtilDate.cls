/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilDate {

    /** Whether Test or not */
    private final static Boolean IS_TEST = Test.isRunningTest();

    /** 기본 포맷 */
    private final static String DEFAULT_FORMAT = 'yyyy-MM-dd\'T\'HH:mm:ss.SSSZ';

    /**
     * @description Current month in Org's Timezone
     * @example Core.Date2.COMPANY_MONTH -> 10
     */
    public final Integer COMPANY_MONTH {
        get{
            if(COMPANY_MONTH == null){
                COMPANY_MONTH = Core.Datetime2.COMPANY_NOW?.month();
            }
            return COMPANY_MONTH;
        }
        set;
    }

    /**
     * @description Current year in Org's Timezone
     * @example Core.Date2.COMPANY_YEAR -> 2024
     */
    public final Integer COMPANY_YEAR {
        get{
            if(COMPANY_YEAR == null){
                COMPANY_YEAR = Core.Datetime2.COMPANY_NOW?.year();
            }
            return COMPANY_YEAR;
        }
        set;
    }

    /**
     * @description Return to GMT time
     * @param dt Datetime
     *
     * @return String
     * @example Core.Date2.toGmtString(Datetime.now()) -> '2024-10-08T04:31:32.207+0000'
     */
    public String toGmtString(Datetime dt){
        return dt?.formatGmt(DEFAULT_FORMAT);
    }

    /**
     * @description Returns GMT time - in specified format
     * @param dt Datetime
     * @param format Format
     *
     * @return String
     * @example Core.Date2.toGmtString(Datetime.now(), 'yyyy-MM-dd') -> '2024-10-08'
     */
    public String toGmtString(Datetime dt, String format){
        return String.isBlank(format) ? toGmtString(dt) : dt?.formatGmt(format);
    }

    /**
     * @description Returns the current time in the User's Timezone
     * @param dt Datetime
     * @param usr User
     *
     * @return String
     * @example Core.Date2.getUserLocalDateTime(Datetime.now(), User) -> '2024-10-08T13:34:05.535+0900'
     */
    public String getUserLocalDateTime(Datetime dt, User usr){
        return dt?.format(DEFAULT_FORMAT, IS_TEST ? 'Asia/Seoul' : usr?.TimeZoneSidKey);
    }

    /**
     * @description Returns the current time in the User's Timezone - in the specified format
     * @param dt Datetime
     * @param usr User
     * @param format Format
     *
     * @return String
     * @example Core.Date2.getUserLocalDateTime(Datetime.now(), User, 'yyyy-MM-dd') -> '2024-10-08'
     */
    public String getUserLocalDateTime(Datetime dt, User usr, String format){
        return String.isBlank(format) ? getUserLocalDateTime(dt, usr) : (dt?.format(format, IS_TEST ? 'Asia/Seoul' : usr?.TimeZoneSidKey));
    }

    /**
     * @description Datetime conversion
     * @param dt String
     *
     * @return String
     * @example Core.Date2.toYYYYMMDD('2024-10-08T13:34:05.535+0900') -> '20241008'
     */
    public String toYYYYMMDD(String dt){
        return String.isBlank(dt) ? null : dt.substringBefore('T').replaceAll('-', '');
    }

    /**
     * @description Datetime 변환
     * @param dt Datetime
     *
     * @return String
     * @example Core.Date2.toYYYYMMDD(Date.today()) -> '20241008'
     */
    public String toYYYYMMDD(Date dt){
        return dt == null ? null : String.valueOf(dt).replaceAll('-', '');
    }

    /**
     * @description Convert Date to yyyyMMdd format String
     * @param d Date
     *
     * @return String
     * @example Core.Date2.toString(Date.today()) -> '20241008'
     */
    public String toString(Date d) {
        return toString(d, 'yyyyMMdd');
    }

    /**
     * @description Convert Date to String in given format
     * @param d Date
     * @param format Format
     *
     * @return String
     * @example Core.Date2.toString(Date.today(), 'yyyy-MM-dd') -> '2024-10-08'
     */
    public String toString(Date d, String format) {
        Datetime dt = d;
        return Core.Datetime2.toString(dt, format);
    }

}