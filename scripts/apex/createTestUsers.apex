// ─── Run this script BEFORE loadTestData.apex ────────────────────────────────
// Creates shelter owner users and assigns the Shelter_Owner permission set.
// Setup objects (User, PermissionSetAssignment) must be in their own transaction.

Profile stdProfile = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
PermissionSet shelterOwnerPs = [SELECT Id FROM PermissionSet WHERE Name = 'Shelter_Owner' LIMIT 1];

// Use last 8 chars of org ID to ensure globally unique usernames
String orgSuffix = UserInfo.getOrganizationId().substring(0, 8).toLowerCase();

User amsterdamOwner = new User(
    FirstName         = 'Amsterdam',
    LastName          = 'Shelter Owner',
    Email             = 'amsterdam.owner@example.com',
    Username          = 'amsterdam.owner.' + orgSuffix + '@animalshelter.dev',
    Alias             = 'amst',
    TimeZoneSidKey    = 'Europe/Amsterdam',
    LocaleSidKey      = 'en_US',
    EmailEncodingKey  = 'UTF-8',
    LanguageLocaleKey = 'en_US',
    ProfileId         = stdProfile.Id
);

User rotterdamOwner = new User(
    FirstName         = 'Rotterdam',
    LastName          = 'Shelter Owner',
    Email             = 'rotterdam.owner@example.com',
    Username          = 'rotterdam.owner.' + orgSuffix + '@animalshelter.dev',
    Alias             = 'rott',
    TimeZoneSidKey    = 'Europe/Amsterdam',
    LocaleSidKey      = 'en_US',
    EmailEncodingKey  = 'UTF-8',
    LanguageLocaleKey = 'en_US',
    ProfileId         = stdProfile.Id
);

insert new List<User>{ amsterdamOwner, rotterdamOwner };

insert new List<PermissionSetAssignment>{
    new PermissionSetAssignment(AssigneeId = amsterdamOwner.Id, PermissionSetId = shelterOwnerPs.Id),
    new PermissionSetAssignment(AssigneeId = rotterdamOwner.Id, PermissionSetId = shelterOwnerPs.Id)
};

System.setPassword(amsterdamOwner.Id, 'Shelter@12345');
System.setPassword(rotterdamOwner.Id, 'Shelter@12345');

System.debug('✔ Users created and Shelter_Owner permission set assigned.');
System.debug('Amsterdam Owner username: ' + amsterdamOwner.Username);
System.debug('Rotterdam Owner username: ' + rotterdamOwner.Username);
System.debug('Password (both): Shelter@12345');
