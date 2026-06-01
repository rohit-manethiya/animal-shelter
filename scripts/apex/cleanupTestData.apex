// Deletes all test data in the correct dependency order.
// Adoption_Request__c first (Master-Detail child of Dog__c),
// then Dog__c (Master-Detail child of Shelter_Facility__c),
// then Shelter_Facility__c.

delete [SELECT Id FROM Adoption_Request__c LIMIT 200];
delete [SELECT Id FROM Dog__c LIMIT 200];
delete [SELECT Id FROM Shelter_Facility__c LIMIT 200];

System.debug('✔ All test data deleted. Run loadTestData.apex to reload.');
