/*
  The SObjects `MetadataPackage`, `MetadataPackageVersion`, and `PackageSubscriber` don't exist in all orgs,
  including scratch orgs - this class uses Strings, dyanmic Apex & dynamic SOQL so this can be bundled into a 2GP
*/

public without sharing class PackageExtractJob implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  private static final Integer BATCH_SIZE = 2000;

  @TestVisible
  private Integer queryLimit;
  @TestVisible
  private Boolean willRunAnotherTime = false;
  @TestVisible
  private List<String> sobjectNames = new List<String>{
    'MetadataPackage',
    'MetadataPackageVersion',
    'PackageSubscriber'
  };

  public void scheduleHourly() {
    System.schedule('Hourly Package Data Extract Job', '0 0 * * * ?', this);
  }

  public void execute(System.SchedulableContext context) {
    Database.executeBatch(this, BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    String currentSObjectName = this.sobjectNames.remove(0);
    return getQueryLocator(currentSObjectName);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    String currentSObjectName = scope.get(0).getSObjectType().getDescribe().getName();

    switch on currentSObjectName {
      when 'MetadataPackage' {
        this.processPackages(scope);
      }
      when 'MetadataPackageVersion' {
        this.processPackageVersions(scope);
      }
      when 'PackageSubscriber' {
        this.processPackageSubscribers(scope);
      }
    }
  }

  public void finish(Database.BatchableContext context) {
    if (this.sobjectNames.isEmpty() == false) {
      this.willRunAnotherTime = true;
      if (Test.isRunningTest() == false) {
        Database.executeBatch(this, BATCH_SIZE);
      }
    }
  }

  private Database.QueryLocator getQueryLocator(String sobjectName) {
    String query;
    switch on sobjectName {
      when 'MetadataPackage' {
        query = 'SELECT Id, Name, NamespacePrefix, PackageCategory, SystemModStamp FROM MetadataPackage';
      }
      when 'MetadataPackageVersion' {
        query = 'SELECT BuildNumber, Id, IsDeprecated, MajorVersion, MetadataPackageid, MinorVersion, Name, PatchVersion, ReleaseState, SystemModStamp FROM MetadataPackageVersion';
      }
      when 'PackageSubscriber' {
        query = 'SELECT Id, InstalledStatus, InstanceName, MetadataPackageId, MetadataPackageVersionId, OrgKey, OrgName, OrgStatus, OrgType, ParentOrg, SystemModStamp FROM PackageSubscriber';
      }
      when else {
        Exception ex = new IllegalArgumentException();
        ex.setMessage('Unsupported SObjectType: ' + sobjectName);
        throw ex;
      }
    }

    if (this.queryLimit != null) {
      query += ' LIMIT ' + this.queryLimit;
    }
    return Database.getQueryLocator(query);
  }

  private void processPackages(List<SObject> metadataPackages) {
    List<Package__c> packages = new List<Package__c>();
    for (SObject metadataPackage : metadataPackages) {
      packages.add(
        new Package__c(
          LastUpdated__c = (Datetime) metadataPackage.get('SystemModStamp'),
          PackageCategory__c = (String) metadataPackage.get('PackageCategory'),
          PackageId__c = Id.valueOf((String) metadataPackage.get('Id')),
          Name = (String) metadataPackage.get('Name'),
          NamespacePrefix__c = (String) metadataPackage.get('NamespacePrefix')
        )
      );
    }
    upsert packages PackageId__c;
  }

  private void processPackageVersions(List<SObject> metadataPackageVersions) {
    List<PackageVersion__c> packageVersions = new List<PackageVersion__c>();
    for (SObject metadataPackageVersion : metadataPackageVersions) {
      packageVersions.add(
        new PackageVersion__c(
          BuildNumber__c = (Decimal) metadataPackageVersion.get('BuildNumber'),
          IsDeprecated__c = (Boolean) metadataPackageVersion.get('IsDeprecated'),
          LastUpdated__c = (Datetime) metadataPackageVersion.get('SystemModStamp'),
          MajorVersion__c = (Decimal) metadataPackageVersion.get('MajorVersion'),
          MinorVersion__c = (Decimal) metadataPackageVersion.get('MinorVersion'),
          Name = truncateFieldValue(Schema.PackageVersion__c.Name, (String) metadataPackageVersion.get('Name')),
          Package__r = new Package__c(
            PackageId__c = Id.valueOf((String) metadataPackageVersion.get('MetadataPackageId'))
          ),
          PatchVersion__c = (Decimal) metadataPackageVersion.get('PatchVersion'),
          ReleaseState__c = (String) metadataPackageVersion.get('ReleaseState'),
          SubscriberPackageVersionId__c = Id.valueOf((String) metadataPackageVersion.get('Id'))
        )
      );
    }
    upsert packageVersions SubscriberPackageVersionId__c;
  }

  private void processPackageSubscribers(List<SObject> packageSubscribers) {
    Map<String, PackageSubscriberOrg__c> parentSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();
    Map<String, PackageSubscriberOrg__c> childSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();

    for (SObject packageSubscriber : packageSubscribers) {
      PackageSubscriberOrg__c org = new PackageSubscriberOrg__c(
        InstalledStatus__c = (String) packageSubscriber.get('InstalledStatus'),
        InstanceName__c = (String) packageSubscriber.get('InstanceName'),
        LastUpdated__c = (Datetime) packageSubscriber.get('SystemModStamp'),
        Name = (String) packageSubscriber.get('OrgName'),
        OrgId__c = Id.valueOf((String) packageSubscriber.get('OrgKey')),
        OrgStatus__c = (String) packageSubscriber.get('OrgStatus'),
        OrgType__c = (String) packageSubscriber.get('OrgType'),
        PackageSubscriberId__c = Id.valueOf((String) packageSubscriber.get('Id')),
        PackageVersion__r = new PackageVersion__c(
          SubscriberPackageVersionId__c = Id.valueOf((String) packageSubscriber.get('MetadataPackageVersionId'))
        )
      );
      if (packageSubscriber.get('ParentOrg') == null) {
        parentSubscriberOrgsByOrgId.put(org.OrgId__c, org);
      } else {
        org.ParentOrgId__c = Id.valueOf((String) packageSubscriber.get('ParentOrg'));
        childSubscriberOrgsByOrgId.put(org.OrgId__c, org);
      }
    }

    // Parent orgs
    upsert parentSubscriberOrgsByOrgId.values() OrgId__c;

    // Child orgs
    for (PackageSubscriberOrg__c childOrg : childSubscriberOrgsByOrgId.values()) {
      if (parentSubscriberOrgsByOrgId.containsKey(childOrg.ParentOrgId__c) == true) {
        childOrg.ParentOrg__c = parentSubscriberOrgsByOrgId.get(childOrg.ParentOrgId__c).Id;
      }
    }
    upsert childSubscriberOrgsByOrgId.values() OrgId__c;
  }

  private static String truncateFieldValue(Schema.SObjectField field, String value) {
    Integer fieldMaxLength = field.getDescribe().getLength();
    return value?.left(fieldMaxLength);
  }
}
