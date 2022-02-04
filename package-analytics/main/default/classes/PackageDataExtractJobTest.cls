//-------------------------------------------------------------------------------------------------//
// This file is part of the Package Analytics project, released under the MIT License.             //
// See LICENSE file or go to https://github.com/jongpie/PackageAnalytics for full license details. //
//-------------------------------------------------------------------------------------------------//

/*
  The SObjects `MetadataPackage`, `MetadataPackageVersion`, and `PackageSubscriber` cannot be created or modified in Apex,
  so this test class uses instances of inner classes in `PackageDataExtractJob` to create mock records.
  When these SObjects *are* present, the data is visible to tests (even without @SeeAllData), so integration tests are also included below.
*/
@IsTest
private class PackageDataExtractJobTest {
  @IsTest
  static void throwsExceptionForUnsupportedSObjectTypeOnStart() {
    // Arrange
    String unsupportedSObjectName = Schema.Account.SObjectType.getDescribe().getName();
    PackageDataExtractJob job = new PackageDataExtractJob();
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
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.sobjectNames = new List<String>{ 'MetadataPackage' };

    // Act
    job.start(null);

    // Assert
    String expectedQuery = 'SELECT Id, Name, NamespacePrefix, PackageCategory, SystemModStamp FROM MetadataPackage';
    System.assertEquals(expectedQuery, job.currentQuery);
  }

  @IsTest
  static void returnsPackageVersionQueryLocatorOnStart() {
    // Arrange
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.sobjectNames = new List<String>{ 'MetadataPackageVersion' };

    // Act
    job.start(null);

    // Assert
    String expectedQuery = 'SELECT BuildNumber, Id, IsDeprecated, MajorVersion, MetadataPackageid, MinorVersion, Name, PatchVersion, ReleaseState, SystemModStamp FROM MetadataPackageVersion';
    System.assertEquals(expectedQuery, job.currentQuery);
  }

  @IsTest
  static void returnsPackageSubscriberQueryLocatorOnStart() {
    // Arrange
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.sobjectNames = new List<String>{ 'PackageSubscriber' };

    // Act
    job.start(null);

    // Assert
    String expectedQuery = 'SELECT Id, InstanceName, MetadataPackageId, MetadataPackageVersionId, OrgKey, OrgName, OrgStatus, OrgType, ParentOrg, SystemModStamp FROM PackageSubscriber';
    System.assertEquals(expectedQuery, job.currentQuery);
  }

  @IsTest
  static void storesPackageDataOnExecute() {
    // Arrange
    PackageDataExtractJob.MetadataPackageInfo metadataPackage = generateMetadataPackageInfo();
    Integer countOfPackageRecords = [SELECT COUNT() FROM Package__c];
    System.assertEquals(0, countOfPackageRecords);

    // Act
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.currentSObjectName = 'MetadataPackage';
    job.execute(null, new List<Object>{ metadataPackage });

    // Assert
    Package__c storedPackage = [
      SELECT LastUpdated__c, PackageCategory__c, PackageId__c, Name, NamespacePrefix__c
      FROM Package__c
    ];
    System.assertEquals(metadataPackage.PackageCategory, storedPackage.PackageCategory__c);
    System.assertEquals(metadataPackage.Id, storedPackage.PackageId__c);
    System.assertEquals(metadataPackage.Name, storedPackage.Name);
    System.assertEquals(metadataPackage.NamespacePrefix, storedPackage.NamespacePrefix__c);
    System.assertEquals(metadataPackage.SystemModStamp, storedPackage.LastUpdated__c);
  }

  @IsTest
  static void storesPackageVersionDataOnExecute() {
    // Arrange
    Package__c storedPackage = generateStoredPackage();
    insert storedPackage;
    PackageDataExtractJob.MetadataPackageVersionInfo metadataPackageVersion = generateMetadataPackageVersionInfo(
      storedPackage.PackageId__c
    );
    Integer countOfPackageVersionRecords = [SELECT COUNT() FROM PackageVersion__c];
    System.assertEquals(0, countOfPackageVersionRecords);

    // Act
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.currentSObjectName = 'MetadataPackageVersion';
    job.execute(null, new List<Object>{ metadataPackageVersion });

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
    System.assertEquals(metadataPackageVersion.BuildNumber, storedPackageVersion.BuildNumber__c);
    System.assertEquals(metadataPackageVersion.IsDeprecated, storedPackageVersion.IsDeprecated__c);
    System.assertEquals(metadataPackageVersion.MajorVersion, storedPackageVersion.MajorVersion__c);
    System.assertEquals(metadataPackageVersion.MinorVersion, storedPackageVersion.MinorVersion__c);
    System.assertEquals(metadataPackageVersion.Name, storedPackageVersion.Name);
    System.assertEquals(storedPackage.Id, storedPackageVersion.Package__c);
    System.assertEquals(metadataPackageVersion.PatchVersion, storedPackageVersion.PatchVersion__c);
    System.assertEquals(metadataPackageVersion.ReleaseState, storedPackageVersion.ReleaseState__c);
    System.assertEquals(metadataPackageVersion.Id, storedPackageVersion.SubscriberPackageVersionId__c);
    System.assertEquals(metadataPackageVersion.SystemModStamp, storedPackageVersion.LastUpdated__c);
  }

  @IsTest
  static void storesPackageVersionDataWithTruncatedName() {
    // Arrange
    Package__c storedPackage = generateStoredPackage();
    insert storedPackage;
    PackageDataExtractJob.MetadataPackageVersionInfo metadataPackageVersion = generateMetadataPackageVersionInfo(
      storedPackage.PackageId__c
    );
    metadataPackageVersion.Name = 'Z'.repeat(10000);
    Integer countOfPackageVersionRecords = [SELECT COUNT() FROM PackageVersion__c];
    System.assertEquals(0, countOfPackageVersionRecords);

    // Act
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.currentSObjectName = 'MetadataPackageVersion';
    job.execute(null, new List<Object>{ metadataPackageVersion });

    // Assert
    Integer fieldMaxLength = Schema.PackageVersion__c.Name.getDescribe().getLength();
    String expectedTruncatedName = metadataPackageVersion.Name.left(fieldMaxLength);
    PackageVersion__c storedPackageVersion = [SELECT Name FROM PackageVersion__c];
    System.assertEquals(expectedTruncatedName, storedPackageVersion.Name);
  }

  @IsTest
  static void storesPackageSubscriberDataOnExecute() {
    // Arrange
    Package__c storedPackage = generateStoredPackage();
    insert storedPackage;
    PackageVersion__c storedPackageVersion = generateStoredPackageVersion(storedPackage.Id);
    insert storedPackageVersion;
    PackageDataExtractJob.PackageSubscriberInfo packageSubscriber = generatePackageSubscriberInfo(
      storedPackageVersion.SubscriberPackageVersionId__c
    );
    Integer countOfPackageSubscriberOrgRecords = [SELECT COUNT() FROM PackageSubscriberOrg__c];
    System.assertEquals(0, countOfPackageSubscriberOrgRecords);

    // Act
    PackageDataExtractJob job = new PackageDataExtractJob();
    job.currentSObjectName = 'PackageSubscriber';
    job.execute(null, new List<Object>{ packageSubscriber });

    // Assert
    PackageSubscriberOrg__c storedPackageSubscriberOrg = [
      SELECT
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
    System.assertEquals(packageSubscriber.Id, storedPackageSubscriberOrg.PackageSubscriberId__c);
    System.assertEquals(packageSubscriber.InstanceName, storedPackageSubscriberOrg.InstanceName__c);
    System.assertEquals(packageSubscriber.OrgName, storedPackageSubscriberOrg.Name);
    System.assertEquals(packageSubscriber.OrgKey, storedPackageSubscriberOrg.OrgId__c);
    System.assertEquals(packageSubscriber.OrgStatus, storedPackageSubscriberOrg.OrgStatus__c);
    System.assertEquals(packageSubscriber.OrgType, storedPackageSubscriberOrg.OrgType__c);
    System.assertEquals(storedPackageVersion.Id, storedPackageSubscriberOrg.PackageVersion__c);
    System.assertEquals(packageSubscriber.SystemModStamp, storedPackageSubscriberOrg.LastUpdated__c);
  }

  @IsTest
  static void startsAnotherRunOnFinishWhenThereAreAdditionalSObjects() {
    // Arrange
    PackageDataExtractJob job = new PackageDataExtractJob();
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
    PackageDataExtractJob job = new PackageDataExtractJob();
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
    if (PackageDataExtractJob.IS_PACKAGING_ORG == false) {
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
    PackageDataExtractJob job = new PackageDataExtractJob();
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
  private static PackageDataExtractJob.MetadataPackageInfo generateMetadataPackageInfo() {
    PackageDataExtractJob.MetadataPackageInfo metadataPackage = new PackageDataExtractJob.MetadataPackageInfo();
    // The actual ID doesn't matter - it just needs to be a real ID
    metadataPackage.Id = UserInfo.getUserId();
    metadataPackage.Name = 'My Amazing 2GP';
    metadataPackage.NamespacePrefix = 'some_namespace';
    metadataPackage.PackageCategory = 'Package2';
    metadataPackage.SystemModStamp = System.now().addDays(-1);

    return metadataPackage;
  }

  private static PackageDataExtractJob.MetadataPackageVersionInfo generateMetadataPackageVersionInfo(
    Id metadataPackageId
  ) {
    PackageDataExtractJob.MetadataPackageVersionInfo metadataPackageVersion = new PackageDataExtractJob.MetadataPackageVersionInfo();
    metadataPackageVersion.BuildNumber = 99;
    // The actual ID doesn't matter - it just needs to be a real ID
    metadataPackageVersion.Id = UserInfo.getUserId();
    metadataPackageVersion.IsDeprecated = false;
    metadataPackageVersion.MajorVersion = 1;
    metadataPackageVersion.MinorVersion = 2;
    metadataPackageVersion.Name = 'The most amazing release!';
    metadataPackageVersion.MetadataPackageId = metadataPackageId;
    metadataPackageVersion.PatchVersion = 13;
    metadataPackageVersion.ReleaseState = 'Beta';
    metadataPackageVersion.SystemModStamp = System.now().addDays(-1);

    return metadataPackageVersion;
  }

  private static PackageDataExtractJob.PackageSubscriberInfo generatePackageSubscriberInfo(
    Id metadataPackageVersionId
  ) {
    PackageDataExtractJob.PackageSubscriberInfo packageSubscriber = new PackageDataExtractJob.PackageSubscriberInfo();
    // The actual ID doesn't matter - it just needs to be a real ID
    packageSubscriber.Id = UserInfo.getUserId();
    packageSubscriber.InstanceName = 'ABC123';
    packageSubscriber.MetadataPackageVersionId = metadataPackageVersionId;
    packageSubscriber.OrgKey = '00D3g0000019YLpEAM';
    packageSubscriber.OrgName = 'My amazing org!';
    packageSubscriber.OrgStatus = 'Demo';
    packageSubscriber.OrgType = 'Sandbox';
    packageSubscriber.SystemModStamp = System.now().addDays(-1);

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
