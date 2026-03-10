$cmdDir = "c:\SFDC Project\JUNHO-DEV-SFDX\force-app\main\default\customMetadata"

$actions = @(
    @{ Code="KILL_SESSION"; Class="SecurityKillSessionAction"; Mode="SYNC" },
    @{ Code="FREEZE_USER"; Class="SecurityFreezeUserAction"; Mode="SYNC" },
    @{ Code="REVOKE_OAUTH_TOKENS"; Class="SecurityRevokeOauthTokensAction"; Mode="SYNC" },
    @{ Code="QUARANTINE_PROFILE"; Class="SecurityQuarantineProfileAction"; Mode="SYNC" },
    @{ Code="REQUIRE_MFA_PASSWORD_RESET"; Class="SecurityResetPasswordAction"; Mode="SYNC" },
    @{ Code="RESTRICT_PERMISSION"; Class="SecurityRestrictPermissionAction"; Mode="SYNC" },
    @{ Code="NOTIFY_SLACK"; Class="SecurityNotifySlackAction"; Mode="ASYNC" },
    @{ Code="NOTIFY_TEAMS"; Class="SecurityNotifyTeamsAction"; Mode="ASYNC" },
    @{ Code="NOTIFY_MANAGER_EMAIL"; Class="SecurityNotifyManagerEmailAction"; Mode="ASYNC" },
    @{ Code="CREATE_CASE"; Class="SecurityCreateCaseAction"; Mode="ASYNC" },
    @{ Code="SEND_TO_SIEM"; Class="SecuritySendToSiemAction"; Mode="ASYNC" }
)

foreach ($a in $actions) {
    $code = $a.Code
    $className = $a.Class
    $mode = $a.Mode
    
    # NeedsToken is historically true for INBOUND webhook approval actions, else false
    $reqToken = "false"
    if ($code -in @("KILL_SESSION", "FREEZE_USER")) { $reqToken = "true" }

    # API Name limits. Replace _ with empty
    $devName = $code -replace '_',''

    $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
    <label>$code</label>
    <protected>false</protected>
    <values>
        <field>ActionClassName__c</field>
        <value xsi:type="xsd:string">$className</value>
    </values>
    <values>
        <field>ExecutionMode__c</field>
        <value xsi:type="xsd:string">$mode</value>
    </values>
    <values>
        <field>InboundActionType__c</field>
        <value xsi:type="xsd:string">$code</value>
    </values>
    <values>
        <field>RequiresToken__c</field>
        <value xsi:type="xsd:boolean">$reqToken</value>
    </values>
</CustomMetadata>
"@
    Set-Content -Path "$cmdDir\SecurityInboundAction.$devName.md-meta.xml" -Value $meta -Encoding UTF8
}

Write-Host "Inbound Action Metadata Update Complete"
