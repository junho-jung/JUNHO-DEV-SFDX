/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public with sharing class Core {

    /** ==================================================================================================
    * @description Datetime
    */
    public static Util_DatetimeUtil Datetime2 {
        get {
            if(Datetime2 == null) {
                Datetime2 = new Util_DatetimeUtil();
            }
            return Datetime2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Date
    */
    public static Util_DateUtil Date2 {
        get {
            if(Date2 == null) {
                Date2 = new Util_DateUtil();
            }
            return Date2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Decimal
    */
    public static Util_DecimalUtil Decimal2 {
        get {
            if(Decimal2 == null) {
                Decimal2 = new Util_DecimalUtil();
            }
            return Decimal2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Encoding
    */
    public static Util_EncodingUtil Encoding2 {
        get {
            if(Encoding2 == null) {
                Encoding2 = new Util_EncodingUtil();
            }
            return Encoding2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Encryption
    */
    /*public static Util_EncryptionUtil Encryption2 {
        get {
            if(Encryption2 == null) {
                Encryption2 = new Util_EncryptionUtil();
            }
            return Encryption2;
        }
        set;
    }*/

    /** ==================================================================================================
    * @description List
    */
    public static Util_HttpUtil Http2 {
        get {
            if(Http2 == null) {
                Http2 = new Util_HttpUtil();
            }
            return Http2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static Util_ListUtil List2 {
        get {
            if(List2 == null) {
                List2 = new Util_ListUtil();
            }
            return List2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Map
    */
    public static Util_MapUtil Map2 {
        get {
            if(Map2 == null) {
                Map2 = new Util_MapUtil();
            }
            return Map2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static Util_ObjectUtil Object2 {
        get {
            if(Object2 == null) {
                Object2 = new Util_ObjectUtil();
            }
            return Object2;
        }
        set;
    }

    /** ==================================================================================================
    * @description String
    */
    public static Util_OrgUtil Org2 {
        get {
            if(Org2 == null) {
                Org2 = new Util_OrgUtil();
            }
            return Org2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Query
    */
    public static Util_QueryUtil Query2 {
        get {
            if(Query2 == null) {
                Query2 = new Util_QueryUtil();
            }
            return Query2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Schema
    */
    public static Util_SchemaUtil Schema2 {
        get {
            if(Schema2 == null) {
                Schema2 = new Util_SchemaUtil();
            }
            return Schema2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static Util_SObjectUtil SObject2 {
        get {
            if(SObject2 == null) {
                SObject2 = new Util_SObjectUtil();
            }
            return SObject2;
        }
        set;
    }

    /** ==================================================================================================
    * @description String
    */
    public static Util_StringUtil String2 {
        get {
            if(String2 == null) {
                String2 = new Util_StringUtil();
            }
            return String2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Trigger
    */
    public static Util_TriggerUtil Trigger2 {
        get {
            if(Trigger2 == null) {
                Trigger2 = new Util_TriggerUtil();
            }
            return Trigger2;
        }
        set;
    }

    /** ==================================================================================================
    * @description User
    */
    public static Util_UserUtil User2 {
        get {
            if(User2 == null) {
                User2 = new Util_UserUtil();
            }
            return User2;
        }
        set;
    }

}