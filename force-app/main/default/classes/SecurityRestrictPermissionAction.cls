/**
* @Author            : jh.jung
* @Description 		 : 
* @Target            : 
* @Modification Log
  Ver      Date            Author           Modification
  ===================================================================================
  1.0      2026-02-03      jh.jung           Created
*/

public class SecurityRestrictPermissionAction extends SecurityBaseAction {
    protected override void doExecute(Map<String, Object> payloadMap, String targetUserId, String originalPayloadJson) {
        if (!Schema.sObjectType.PermissionSetAssignment.isDeletable()) {
            throw new SecurityException('No delete access to PermissionSetAssignment.');
        }

        if (String.isBlank(targetUserId)) return;

        // Default restriction list (can be extended later via CMDT)
        Set<String> restrictedPermSets = new Set<String>{
            'ModifyAllData',
            'ViewAllData'
        };

        List<PermissionSetAssignment> psa = [
            SELECT Id, PermissionSet.Name, AssigneeId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :targetUserId
        ];

        List<PermissionSetAssignment> toDelete = new List<PermissionSetAssignment>();
        for (PermissionSetAssignment a : psa) {
            if (restrictedPermSets.contains(a.PermissionSet.Name)) {
                toDelete.add(a);
            }
        }
        if (toDelete.isEmpty()) return;

        Database.delete(toDelete, false);
    }
}