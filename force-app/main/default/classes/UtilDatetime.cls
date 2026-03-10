/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilDatetime {


    /**
     * @description Current time in Org's Timezone
     * @example Core.Datetime2.COMPANY_NOW
     */
    public final Datetime COMPANY_NOW {
        get{
            if(COMPANY_NOW == null){
                //String strCompanyNow = Datetime.now().format('yyyy-MM-dd HH:mm:ss', OrgUtil.ORG_SETTING.TimeZoneSidKey);
                //COMPANY_NOW = Datetime.valueOf(strCompanyNow);
            }
            return COMPANY_NOW;
        }
        set;
    }

    /**
     * @description String -> Datetime
     * @param str String
     *
     * @return  ==> Date type
     * @example Core.Datetime2.toDatetime('2023-04-06T06:21:15.000+00:00') -> 2023-04-06 06:21:15
     */
    public Datetime toDatetime(String str) {
        Datetime d = (Datetime) JSON.deserialize('"' + str + '"', Datetime.class);
        return d;
    }

    /**
     * @description Object -> Datetime
     * @param obj Object
     *
     * @return Datetime
     * @example Core.Datetime2.nvl(Object);
     */
    public Datetime nvl(Object obj) {
        return obj == null ? null : Datetime.valueOf(obj);
    }

    /**
     * @description Returns the given Datetime in Timezone time zone.
     * @param sObj SObject
     * @param fieldApi Field API
     *
     * @return Datetime
     * @example Core.Datetime2.toDatetime(Record, 'CreatedDate');
     */
    public Datetime toDatetime(SObject sObj, String fieldApi) {
        Object value = sObj.get(fieldApi);
        return nvl(value);
    }

    /**
     * @description Extract the corresponding field from SObject and convert it to Datetime
     * @param dt Datetime
     * @param format Foramt
     *
     * @return String
     * @example Core.Datetime2.toString(Datetime.now(), 'yyyyMMdd');
     */
    public String toString(Datetime dt, String format) {
        return dt.format(format);
    }

    /**
     * @description Convert Datetime to yyyyMMdd format String
     * @param dt Datetime
     *
     * @return String
     * @example Core.Datetime2.toString(Datetime.now());
     */
    public String toString(Datetime dt) {
        return toString(dt, 'yyyyMMdd');
    }

    /**
     * @description Returns the given Datetime in Timezone time zone.
     * @param dt Datetime
     * @param timeZoneKey TimeZoneKey
     *
     * @return String
     * @example Core.Datetime2.getLocalDatetime(Datetime.now(), 'America/Newyork');
     */
    public String getLocalDateTime(Datetime dt, String timeZoneKey) {
        return dt?.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ', timeZoneKey);
    }
}