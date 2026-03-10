$classDir = "c:\SFDC Project\JUNHO-DEV-SFDX\force-app\main\default\classes"

function Write-ApexComponent($name, $content) {
    $meta = @"
<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>59.0</apiVersion>
    <status>Active</status>
</ApexClass>
"@
    Set-Content -Path "$classDir\$name.cls" -Value $content -Encoding UTF8
    Set-Content -Path "$classDir\$name.cls-meta.xml" -Value $meta -Encoding UTF8
}

$policyResolver = @"
/**
 * @Description Extract policy merging logic from Handler
 */
public with sharing class SecurityPolicyResolver {
    public static Set<String> mergePolicies(SecurityAlertHandler.AlertRecord alert, Decimal alertCount, out SecurityPolicy__mdt matchedPolicy) {
        List<String> mergedTypes = new List<String>();
        SecurityPolicy__mdt policy = null;
        matchedPolicy = null;

        if (!String.isBlank(alert.PolicyCode)) {
            try {
                policy = SecurityGuard.getPolicy(alert.PolicyCode);
                matchedPolicy = policy;
                if (policy != null) {
                    Boolean matchedDynamic = false;

                    if (policy.ThresholdCritical__c != null && alertCount >= policy.ThresholdCritical__c && !String.isBlank(policy.ActionCritical__c)) {
                        mergedTypes.addAll(policy.ActionCritical__c.split(';'));
                        matchedDynamic = true;
                    } else if (policy.ThresholdMedium__c != null && alertCount >= policy.ThresholdMedium__c && !String.isBlank(policy.ActionMedium__c)) {
                        mergedTypes.addAll(policy.ActionMedium__c.split(';'));
                        matchedDynamic = true;
                    } else if (policy.ThresholdLow__c != null && alertCount >= policy.ThresholdLow__c && !String.isBlank(policy.ActionLow__c)) {
                        mergedTypes.addAll(policy.ActionLow__c.split(';'));
                        matchedDynamic = true;
                    }

                    if (!matchedDynamic && !String.isBlank(policy.ActionTypes__c)) {
                        mergedTypes.addAll(policy.ActionTypes__c.split(';'));
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'SecurityPolicyResolver ::: Failed: ' + e.getMessage());
            }
        }

        if (!String.isBlank(alert.ActionType)) {
            mergedTypes.addAll(alert.ActionType.split(';'));
        }

        Set<String> finalTypes = new Set<String>();
        for (String t : mergedTypes) {
            String tt = t != null ? t.trim() : null;
            if (!String.isBlank(tt)) {
                finalTypes.add(tt);
            }
        }
        return finalTypes;
    }
}
"@

$iFilter = @"
public interface ISecurityFilter {
    Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc);
}
"@

$throttleFilter = @"
public class SecurityThrottleFilter implements ISecurityFilter {
    public Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc) {
        if (actionDesc == null || actionDesc.action == null) return false;
        String logActionName = String.valueOf(actionDesc.action).substringBefore(':');
        if (SecurityActionThrottle.isThrottled(alert.UserId, alert.PolicyCode, logActionName)) {
            System.debug(LoggingLevel.WARN, 'SecurityThrottleFilter ::: Throttled: ' + actionType);
            return false;
        }
        return true;
    }
}
"@

$filterChain = @"
public class SecurityFilterChain {
    private static List<ISecurityFilter> filters = new List<ISecurityFilter>{
        new SecurityThrottleFilter()
    };

    public static Boolean isAllowed(SecurityAlertHandler.AlertRecord alert, String actionType, SecurityTypes.ActionDescriptor actionDesc) {
        for (ISecurityFilter filter : filters) {
            if (!filter.isAllowed(alert, actionType, actionDesc)) {
                return false;
            }
        }
        return true;
    }
}
"@

Write-ApexComponent "SecurityPolicyResolver" $policyResolver
Write-ApexComponent "ISecurityFilter" $iFilter
Write-ApexComponent "SecurityThrottleFilter" $throttleFilter
Write-ApexComponent "SecurityFilterChain" $filterChain

Write-Host "Done"
