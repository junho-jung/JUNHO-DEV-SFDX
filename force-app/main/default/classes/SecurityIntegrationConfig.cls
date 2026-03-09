// 🔔 Deprecated:
//  - 초기 설계에서는 SecurityIntegration__mdt + 이 유틸로 통합 설정을 읽었으나,
//    현재는 InterfaceConfig__mdt + SecurityIntegration__c + SecurityInterfaceBridge 를 사용하므로
//    이 클래스는 더 이상 사용하지 않습니다.
//  - 유지보수 편의를 위해 소스에는 남겨두되, 참조는 하지 않도록 합니다.
public with sharing class SecurityIntegrationConfig {}