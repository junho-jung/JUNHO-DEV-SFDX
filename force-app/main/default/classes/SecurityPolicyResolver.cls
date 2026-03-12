public with sharing class SecurityPolicyResolver {
    public class Result {
        public Set<String> actionTypes;
        public SecurityPolicy__mdt policy;
        
        public Result(Set<String> types, SecurityPolicy__mdt p) {
            this.actionTypes = types;
            this.policy = p;
        }
    }

    public static Result mergePolicies(SecurityAlertHandler.AlertRecord alert, Decimal alertCount) {
        List<String> mergedTypes = new List<String>();
        SecurityPolicy__mdt policy = null;

        if (!String.isBlank(alert.PolicyCode)) {
            try {
                policy = SecurityGuard.getPolicy(alert.PolicyCode);
                if (policy != null) {
                    Boolean matchedDynamic = false;

                    if (policy.ThresholdCritical__c != null && alertCount >= policy.ThresholdCritical__c && !String.isBlank(policy.ActionCritical__c)) {
                        mergedTypes.addAll(policy.ActionCritical__c.split(';'));
                        matchedDynamic = true;
                    } else if (policy.ThresholdHigh__c != null && alertCount >= policy.ThresholdHigh__c && !String.isBlank(policy.ActionHigh__c)) {
                        mergedTypes.addAll(policy.ActionHigh__c.split(';'));
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
        
        return new Result(finalTypes, policy);
    }
}