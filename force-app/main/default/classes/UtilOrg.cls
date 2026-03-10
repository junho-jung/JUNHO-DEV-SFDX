/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilOrg {

    /** Whether Test or not */
    private final Boolean IS_TEST = Test.isRunningTest();

    /**
     * @description Org 정보
     */
    public final Organization ORG_INFO {
        get{
            if(ORG_INFO == null){
                ORG_INFO = [SELECT Id, TimeZoneSidKey FROM Organization WHERE Id = :UserInfo.getOrganizationId() LIMIT 1];
            }
            return ORG_INFO;
        }
        set;
    }

    /**
     * @description Sandbox 이름 조회
     */
    public String ORG_NAME {
        get{
            if(ORG_NAME == null){
                ORG_NAME = System.DomainParser.parse(Url.getOrgDomainUrl()).getSandboxName();
            }
            return ORG_NAME;
        }
        set;
    }

    /**
     * @description 현재 접속한 환경이 Site인지 확인
     */
    public final Boolean IS_COMMUNITY {
        get{
            if(IS_COMMUNITY == null){
                IS_COMMUNITY = String.isNotBlank(Site.getSiteId());
            }
            return IS_COMMUNITY;
        }
        set;
    }

    /**
     * @description Domain URL
     */
    public String DOMAIN_URL {
        get{
            if(DOMAIN_URL == null){
                DOMAIN_URL =  (IS_COMMUNITY ? [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :Site.getSiteId() LIMIT 1].SecureUrl : Url.getOrgDomainUrl().toExternalForm()) + '/';
            }
            return DOMAIN_URL;
        }
        set;
    }

    /** Org 전반적인 설정 커스텀 세팅 */
    public final Setting__c ORG_SETTING {
        get{
            if(ORG_SETTING == null){
                ORG_SETTING = Setting__c.getOrgDefaults();
            }
            return ORG_SETTING;
        }
        set;
    }

    /** 특정 프로필에 대한 커스텀 세팅 */
    public final Setting__c INSTANCE_SETTING {
        get{
            if(INSTANCE_SETTING == null){
                INSTANCE_SETTING = Setting__c.getInstance(UserInfo.getProfileId());
            }
            return INSTANCE_SETTING;
        }
        set;
    }

    /**
     * @description Session Id 조회
     */
    public String SESSION_ID {
        get{
            if(SESSION_ID == null){
                if(String.isBlank(System.Network.getNetworkId())){
                    PageReference reportPage = Page.UserSessionId;
                    String vfContent = IS_TEST ? 'StartTestEnd' : reportPage.getContent().toString();
                    Integer startP = vfContent.indexOf('Start') + 'Start'.length();
                    Integer endP = vfContent.indexOf('End');
                    SESSION_ID = vfContent.substring(startP, endP);
                }else{
                    SESSION_ID = UserInfo.getSessionId();
                }
            }
            return SESSION_ID;
        }
        set;
    }

    /**
     * @author sy.lee
     * @description Org Wide Email Address 조회
     */
    public List<OrgWideEmailAddress> OWE_LIST {
        get{
            if(OWE_LIST == null){
                OWE_LIST = [SELECT Id FROM OrgWideEmailAddress LIMIT 1];
            }
            return OWE_LIST;
        }
        set;
    }

}