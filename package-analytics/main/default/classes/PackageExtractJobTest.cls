/*
  The SObjects `MetadataPackage`, `MetadataPackageVersion`, and `PackageSubscriber` cannot be created or modified in Apex,
  so this test class uses instances of `SObject` & some classic JSON deserialization methods to create mock records.
  When these SObjects *are* present, the data is visible to tests (even without @SeeAllData), so integration tests are also included below.
*/
@IsTest
private class PackageExtractJobTest {
  @IsTest
  static void throwsExceptionForUnsupportedSObjectTypeOnStart() {
    // Arrange
    String unsupportedSObjectName = Schema.Account.SObjectType.getDescribe().getName();
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{ unsupportedSObjectName };

    try {
      // Act
      job.start(null);
      System.assert(false, 'Exception expected on previous line');
    } catch (IllegalArgumentException ex) {
      // Assert
      System.assertEquals('Unsupported SObjectType: ' + unsupportedSObjectName, ex.getMessage());
    }
  }

  @IsTest
  static void returnsPackageQueryLocatorOnStart() {
    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{ 'MetadataPackage' };

    // Act
    Database.QueryLocator queryLocator = job.start(null);

    // Assert
    String expectedQuery = Database.getQueryLocator(
        'SELECT Id, Name, NamespacePrefix, PackageCategory, SystemModStamp FROM MetadataPackage'
      )
      .getQuery();
    System.assertEquals(expectedQuery, queryLocator.getQuery());
  }

  @IsTest
  static void returnsPackageVersionQueryLocatorOnStart() {
    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{ 'MetadataPackageVersion' };

    // Act
    Database.QueryLocator queryLocator = job.start(null);

    // Assert
    String expectedQuery = Database.getQueryLocator(
        'SELECT BuildNumber, Id, IsDeprecated, MajorVersion, MetadataPackageid, MinorVersion, Name, PatchVersion, ReleaseState, SystemModStamp FROM MetadataPackageVersion'
      )
      .getQuery();
    System.assertEquals(expectedQuery, queryLocator.getQuery());
  }

  @IsTest
  static void returnsPackageSubscriberQueryLocatorOnStart() {
    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{ 'PackageSubscriber' };

    // Act
    Database.QueryLocator queryLocator = job.start(null);

    // Assert
    String expectedQuery = Database.getQueryLocator(
        'SELECT Id, InstalledStatus, InstanceName, MetadataPackageId, MetadataPackageVersionId, OrgKey, OrgName, OrgStatus, OrgType, ParentOrg, SystemModStamp FROM PackageSubscriber'
      )
      .getQuery();
    System.assertEquals(expectedQuery, queryLocator.getQuery());
  }

  @IsTest
  static void storesPackageDataOnExecute() {
    // Arrange
    SObject metadataPackage = generateMetadataPackage();
    Integer countOfPackageRecords = [SELECT COUNT() FROM Package__c];
    System.assertEquals(0, countOfPackageRecords);

    // Act
    PackageExtractJob job = new PackageExtractJob();
    job.execute(null, new List<SObject>{ metadataPackage });

    // Assert
    Package__c storedPackage = [
      SELECT LastUpdated__c, PackageCategory__c, PackageId__c, Name, NamespacePrefix__c
      FROM Package__c
    ];
    System.assertEquals((String) metadataPackage.get('PackageCategory'), storedPackage.PackageCategory__c);
    System.assertEquals(Id.valueOf((String) metadataPackage.get('Id')), storedPackage.PackageId__c);
    System.assertEquals((String) metadataPackage.get('Name'), storedPackage.Name);
    System.assertEquals((String) metadataPackage.get('NamespacePrefix'), storedPackage.NamespacePrefix__c);
    System.assertEquals((Datetime) metadataPackage.get('SystemModStamp'), storedPackage.LastUpdated__c);
  }

  @IsTest
  static void storesPackageVersionDataOnExecute() {
    // Arrange
    Package__c storedPackage = generateStoredPackage();
    insert storedPackage;
    SObject metadataPackageVersion = generateMetadataPackageVersion(storedPackage.PackageId__c);
    Integer countOfPackageVersionRecords = [SELECT COUNT() FROM PackageVersion__c];
    System.assertEquals(0, countOfPackageVersionRecords);

    // Act
    PackageExtractJob job = new PackageExtractJob();
    job.execute(null, new List<SObject>{ metadataPackageVersion });

    // Assert
    PackageVersion__c storedPackageVersion = [
      SELECT
        BuildNumber__c,
        IsDeprecated__c,
        LastUpdated__c,
        MajorVersion__c,
        MinorVersion__c,
        Name,
        Package__c,
        PatchVersion__c,
        ReleaseState__c,
        SubscriberPackageVersionId__c
      FROM PackageVersion__c
    ];
    System.assertEquals((Decimal) metadataPackageVersion.get('BuildNumber'), storedPackageVersion.BuildNumber__c);
    System.assertEquals((Boolean) metadataPackageVersion.get('IsDeprecated'), storedPackageVersion.IsDeprecated__c);
    System.assertEquals((Decimal) metadataPackageVersion.get('MajorVersion'), storedPackageVersion.MajorVersion__c);
    System.assertEquals((Decimal) metadataPackageVersion.get('MinorVersion'), storedPackageVersion.MinorVersion__c);
    System.assertEquals((String) metadataPackageVersion.get('Name'), storedPackageVersion.Name);
    System.assertEquals(storedPackage.Id, storedPackageVersion.Package__c);
    System.assertEquals((Decimal) metadataPackageVersion.get('PatchVersion'), storedPackageVersion.PatchVersion__c);
    System.assertEquals((String) metadataPackageVersion.get('ReleaseState'), storedPackageVersion.ReleaseState__c);
    System.assertEquals((String) metadataPackageVersion.get('Id'), storedPackageVersion.SubscriberPackageVersionId__c);
    System.assertEquals((Datetime) metadataPackageVersion.get('SystemModStamp'), storedPackageVersion.LastUpdated__c);
  }

  @IsTest
  static void storesPackageSubscriberDataOnExecute() {
    // Arrange
    Package__c storedPackage = generateStoredPackage();
    insert storedPackage;
    PackageVersion__c storedPackageVersion = generateStoredPackageVersion(storedPackage.Id);
    insert storedPackageVersion;
    SObject packageSubscriber = generatePackageSubscriber(storedPackageVersion.SubscriberPackageVersionId__c);
    Integer countOfPackageSubscriberOrgRecords = [SELECT COUNT() FROM PackageSubscriberOrg__c];
    System.assertEquals(0, countOfPackageSubscriberOrgRecords);

    // Act
    PackageExtractJob job = new PackageExtractJob();
    job.execute(null, new List<SObject>{ packageSubscriber });

    // Assert
    PackageSubscriberOrg__c storedPackageSubscriberOrg = [
      SELECT
        InstalledStatus__c,
        InstanceName__c,
        LastUpdated__c,
        Name,
        OrgId__c,
        OrgStatus__c,
        OrgType__c,
        PackageSubscriberId__c,
        PackageVersion__c
      FROM PackageSubscriberOrg__c
    ];
    System.assertEquals(
      Id.valueOf((String) packageSubscriber.get('Id')),
      storedPackageSubscriberOrg.PackageSubscriberId__c
    );
    System.assertEquals(
      (String) packageSubscriber.get('InstalledStatus'),
      storedPackageSubscriberOrg.InstalledStatus__c
    );
    System.assertEquals((String) packageSubscriber.get('InstanceName'), storedPackageSubscriberOrg.InstanceName__c);
    System.assertEquals((String) packageSubscriber.get('OrgName'), storedPackageSubscriberOrg.Name);
    System.assertEquals(Id.valueOf((String) packageSubscriber.get('OrgKey')), storedPackageSubscriberOrg.OrgId__c);
    System.assertEquals((String) packageSubscriber.get('OrgStatus'), storedPackageSubscriberOrg.OrgStatus__c);
    System.assertEquals((String) packageSubscriber.get('OrgType'), storedPackageSubscriberOrg.OrgType__c);
    System.assertEquals(storedPackageVersion.Id, storedPackageSubscriberOrg.PackageVersion__c);
    System.assertEquals((Datetime) packageSubscriber.get('SystemModStamp'), storedPackageSubscriberOrg.LastUpdated__c);
  }

  @IsTest
  static void startsAnotherRunOnFinishWhenThereAreAdditionalSObjects() {
    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{ 'MetadataPackageVersion', 'PackageSubscriber' };
    System.assertEquals(false, job.willRunAnotherTime);

    // Act
    job.finish(null);

    // Assert
    System.assertEquals(false, job.sobjectNames.isEmpty());
    System.assertEquals(true, job.willRunAnotherTime);
  }

  @IsTest
  static void doesNotStartAnotherRunOnFinishWhenThereAreNoMoreSObjects() {
    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.sobjectNames = new List<String>{};
    System.assertEquals(false, job.willRunAnotherTime);

    // Act
    job.finish(null);

    // Assert
    System.assertEquals(true, job.sobjectNames.isEmpty());
    System.assertEquals(false, job.willRunAnotherTime);
  }

  @IsTest
  static void runsBatchJobForMetadataPackageWhenOrgIsDevHub() {
    // Integration test - this can only run in dev hubs that have 1+ packages, so use a few guard clauses to see if this test can run
    // Global describe - yuck!
    if (Schema.getGlobalDescribe().containsKey('MetadataPackage') == false) {
      System.debug(
        LoggingLevel.INFO,
        'Current org does not have the SObject MetadataPackage, skipping integration test'
      );
      return;
    }
    if (Database.countQuery('SELECT COUNT() FROM MetadataPackage') == 0) {
      System.debug(
        LoggingLevel.INFO,
        'Current org does not have any data in MetadataPackage, skipping integration test'
      );
      return;
    }

    // Arrange
    PackageExtractJob job = new PackageExtractJob();
    job.queryLimit = 1;

    // Act
    Test.startTest();
    Database.executeBatch(job);
    Test.stopTest();

    // Assert
    SObject metadataPackage = Database.query(
      'SELECT PackageCategory, Id, Name, NamespacePrefix, SystemModStamp FROM MetadataPackage LIMIT 1'
    );
    Package__c storedPackage = [
      SELECT LastUpdated__c, PackageCategory__c, PackageId__c, Name, NamespacePrefix__c
      FROM Package__c
    ];
    System.assertEquals((String) metadataPackage.get('PackageCategory'), storedPackage.PackageCategory__c);
    System.assertEquals(Id.valueOf((String) metadataPackage.get('Id')), storedPackage.PackageId__c);
    System.assertEquals((String) metadataPackage.get('Name'), storedPackage.Name);
    System.assertEquals((String) metadataPackage.get('NamespacePrefix'), storedPackage.NamespacePrefix__c);
    System.assertEquals((Datetime) metadataPackage.get('SystemModStamp'), storedPackage.LastUpdated__c);
  }

  // TODO - add additional integration tests for MetadataPackageVersion & PackageSubscriber

  // Helper methods
  private static SObject generateMetadataPackage() {
    Map<String, Object> sobjectAttributes = new Map<String, Object>{ 'type' => 'MetadataPackage' };
    Map<String, Object> metadataPackageUntyped = new Map<String, Object>{
      'attributes' => sobjectAttributes,
      'Id' => UserInfo.getUserId(), // The actual ID doesn't matter - it just needs to be a real ID
      'Name' => 'My Amazing 2GP',
      'NamespacePrefix' => 'some_namespace',
      'PackageCategory' => 'Package2',
      'SystemModStamp' => System.now().addDays(-1)
    };

    String metadataPackageJson = JSON.serialize(metadataPackageUntyped);
    SObject metadataPackage = (SObject) JSON.deserialize(metadataPackageJson, SObject.class);

    return metadataPackage;
  }

  private static SObject generateMetadataPackageVersion(Id metadataPackageId) {
    Map<String, Object> sobjectAttributes = new Map<String, Object>{ 'type' => 'MetadataPackageVersion' };
    Map<String, Object> metadataPackageVersionUntyped = new Map<String, Object>{
      'attributes' => sobjectAttributes,
      'BuildNumber' => 99,
      'Id' => UserInfo.getUserId(), // The actual ID doesn't matter - it just needs to be a real ID
      'IsDeprecated' => false,
      'MajorVersion' => 1,
      'MinorVersion' => 2,
      'Name' => 'The most amazing release!',
      'MetadataPackageId' => metadataPackageId,
      'PatchVersion' => 13,
      'ReleaseState' => 'Beta',
      'SystemModStamp' => System.now().addDays(-1)
    };

    String metadataPackageVersionJson = JSON.serialize(metadataPackageVersionUntyped);
    SObject metadataPackageVersion = (SObject) JSON.deserialize(metadataPackageVersionJson, SObject.class);

    return metadataPackageVersion;
  }

  private static SObject generatePackageSubscriber(Id metadataPackageVersionId) {
    Map<String, Object> sobjectAttributes = new Map<String, Object>{ 'type' => 'PackageSubscriber' };
    Map<String, Object> packageSubscriberUntyped = new Map<String, Object>{
      'attributes' => sobjectAttributes,
      'Id' => '0Hb01000000E08hABC',
      'InstalledStatus' => 'i',
      'InstanceName' => 'ABC123',
      'MetadataPackageVersionId' => metadataPackageVersionId,
      'OrgKey' => '00D3g0000019YLpEAM',
      'OrgName' => 'My amazing org!',
      'OrgStatus' => 'Demo',
      'OrgType' => 'Sandbox',
      'SystemModStamp' => System.now().addDays(-1)
    };

    String packageSubscriberJson = JSON.serialize(packageSubscriberUntyped);
    SObject packageSubscriber = (SObject) JSON.deserialize(packageSubscriberJson, SObject.class);

    return packageSubscriber;
  }

  private static Package__c generateStoredPackage() {
    return new Package__c(Name = 'some package', PackageId__c = UserInfo.getUserId());
  }

  private static PackageVersion__c generateStoredPackageVersion(Id storedPackageId) {
    return new PackageVersion__c(
      Name = 'some package version',
      Package__c = storedPackageId,
      SubscriberPackageVersionId__c = UserInfo.getUserId()
    );
  }
}
