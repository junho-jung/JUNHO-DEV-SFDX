/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-01-30      jh.jung           Created
*/
trigger SecurityAlert on SecurityAlert__e (after insert) {
    System.debug('Security_Alert trigger catch');
    TriggerHandler.runTriggerByCustomMeta(this);
}