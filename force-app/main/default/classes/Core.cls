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
    public static UtilDatetime Datetime2 {
        get {
            if(Datetime2 == null) {
                Datetime2 = new UtilDatetime();
            }
            return Datetime2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Date
    */
    public static UtilDate Date2 {
        get {
            if(Date2 == null) {
                Date2 = new UtilDate();
            }
            return Date2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Decimal
    */
    public static UtilDecimal Decimal2 {
        get {
            if(Decimal2 == null) {
                Decimal2 = new UtilDecimal();
            }
            return Decimal2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Encoding
    */
    public static UtilEncoding Encoding2 {
        get {
            if(Encoding2 == null) {
                Encoding2 = new UtilEncoding();
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
    public static UtilHttp Http2 {
        get {
            if(Http2 == null) {
                Http2 = new UtilHttp();
            }
            return Http2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static UtilList List2 {
        get {
            if(List2 == null) {
                List2 = new UtilList();
            }
            return List2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Map
    */
    public static UtilMap Map2 {
        get {
            if(Map2 == null) {
                Map2 = new UtilMap();
            }
            return Map2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static UtilObject Object2 {
        get {
            if(Object2 == null) {
                Object2 = new UtilObject();
            }
            return Object2;
        }
        set;
    }

    /** ==================================================================================================
    * @description String
    */
    public static UtilOrg Org2 {
        get {
            if(Org2 == null) {
                Org2 = new UtilOrg();
            }
            return Org2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Query
    */
    public static UtilQuery Query2 {
        get {
            if(Query2 == null) {
                Query2 = new UtilQuery();
            }
            return Query2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Schema
    */
    public static UtilSchema Schema2 {
        get {
            if(Schema2 == null) {
                Schema2 = new UtilSchema();
            }
            return Schema2;
        }
        set;
    }

    /** ==================================================================================================
    * @description List
    */
    public static UtilSObject SObject2 {
        get {
            if(SObject2 == null) {
                SObject2 = new UtilSObject();
            }
            return SObject2;
        }
        set;
    }

    /** ==================================================================================================
    * @description String
    */
    public static UtilString String2 {
        get {
            if(String2 == null) {
                String2 = new UtilString();
            }
            return String2;
        }
        set;
    }

    /** ==================================================================================================
    * @description Trigger
    */
    public static UtilTrigger Trigger2 {
        get {
            if(Trigger2 == null) {
                Trigger2 = new UtilTrigger();
            }
            return Trigger2;
        }
        set;
    }

    /** ==================================================================================================
    * @description User
    */
    public static UtilUser User2 {
        get {
            if(User2 == null) {
                User2 = new UtilUser();
            }
            return User2;
        }
        set;
    }

}