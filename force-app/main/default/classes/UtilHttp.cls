/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2025-11-24      jh.jung           Created
*/
public without sharing class UtilHttp {

    /**
     * @description Http Query Parameter 추가
     * ex) String endPoint = Util_ApexUtil.setEndpoint(END_POINT)
                    .append('sort', sortedBy)
                    .build();
     */
    public class ParameterBuilder {
        private String url;

        public ParameterBuilder(String url) {
            this.url = url;
        }

        public ParameterBuilder append(String key, String value) {
            url += (url.contains('?') ? ('&' + key + '=' + value) : ('?' + key + '=' + value));
            return this;
        }

        public String build() {
            return url;
        }
    }

    /**
     * @description Set EndPoint to builder
     * @param url URL
     *
     * @return ParameterBuilder
     */
    public ParameterBuilder setEndpoint(String url){
        return new ParameterBuilder(url);
    }

    /**
     * @description Call current org itself
     * @param method HTTP Method
     * @param path Path (ex) /services/data/v58.0/analytics/reports/{0}/describe)
     *
     * @return HttpResponse
     */
    public HttpResponse currentOrg(String method, String path){
        String endPoint = 'callout:CurrentOrg' + path;
        HttpRequest httpRequest = new HttpRequest();
        httpRequest.setMethod(method);
        httpRequest.setEndpoint(endPoint);
        Http http = new Http();
        return http.send(httpRequest);
    }

}