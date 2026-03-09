/**
 * @Description 플랫폼 이벤트(SecurityAlert__e) 발행 실패 시 Fallback.
 *              EventBus.publish 실패 시 본 Queueable이 대신 핸들러 로직을 실행.
 */
public class SecurityAlertFallbackJob implements Queueable {

    private String fallbackJson;

    /**
     * @param fallbackJson SecurityAlertHandler.AlertRecord 직렬화 JSON
     */
    public SecurityAlertFallbackJob(String fallbackJson) {
        this.fallbackJson = fallbackJson;
    }

    public void execute(QueueableContext ctx) {
        SecurityAlertHandler.processAlertsFromFallback(this.fallbackJson);
    }
}