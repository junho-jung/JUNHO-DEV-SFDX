public with sharing class AccountController {

    public AccountController() {}
    

    // 조회중인 Contact의 accountId을 갖고있는 모든 Contact를 List로 조회
    @AuraEnabled
    public static List<Contact> getContactListByEqualAccount(Id recordId) {
        System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@ getContactListByEqualAccount start');

        List<Contact> targetAccount = [SELECT Id, AccountId FROM Contact WHERE Id = :recordId];

        if(!targetAccount.isEmpty()) {
            System.debug('recordId:::::::::::::'+recordId);
            List<Contact> contactListEqualAccountId = [SELECT FirstName, LastName, Email, Account.Name FROM Contact WHERE AccountId = :targetAccount[0].AccountId];
            System.debug('contactListEqualAccountId::::' + contactListEqualAccountId);
            return contactListEqualAccountId;
        }
        return null;

        // 서브쿼리
        // List<Contact> contactListByAccountId = [SELECT FirstName, LastName, Email FROM Contact WHERE AccountId IN (SELECT AccountId FROM Contact WHERE = :recordId)];
        // System.debug('contactListByAccountId:::::::::::::::::::' + contactListByAccountId);
        // return contactListByAccountId;
    }

    // Contact 생성
    @AuraEnabled
    public static String createContact(Id accountId, String FirstName, String LastName, String Email) {
        try{
            System.debug('@@@@@@@@@@@@@@@@@@@@@@@@@@ createContact start');
            System.debug('accountId:::::::::::::::::::::::'+accountId);
            Contact newContact = new Contact();
            newContact.AccountId = accountId;
            newContact.FirstName = FirstName;
            newContact.LastName = LastName;
            newContact.Email = Email;
    
            insert newContact;
            return '성공';
        } catch(Exception e) {
            return e.getMessage();
        }
    }
}