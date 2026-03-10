/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilDecimal {

    /**
      * @description Decimal Null Value
      * @param val1 original value
      * @param val2 value to be replaced
      *
      * @return Decimal
      */
    public Decimal nvl(Decimal val1, Decimal val2) {
        return val1 ?? val2;
    }

    /**
     * @description String to Decimal
     * @param val value
     *
     * @return Decimal
     */
    public Decimal toDecimal(String val) {
        return val == null ? null : Decimal.valueOf(val);
    }

}