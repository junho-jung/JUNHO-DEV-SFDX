/**
 * [2단계] 인바운드 비즈니스 로직 인터페이스.
 *         InboundRestHandler.run()에서 호출. SecurityActionInboundHandler가 구현.
 */
public interface IInboundAction {
    InboundRestHandler.InboundResult run(String method, String requestBody, Map<String, String> queryParams);
}