public without sharing class PackageExtractJob implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  private static final Integer BATCH_SIZE = 2000;
  @TestVisible
  private static final Boolean IS_DEV_HUB {
    get {
      if (IS_DEV_HUB == null) {
        IS_DEV_HUB = Schema.getGlobalDescribe().containsKey('MetadataPackage');
      }
      return IS_DEV_HUB;
    }
    set;
  }

  @TestVisible
  private String currentQuery;
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
  @TestVisible
  private String currentSObjectName;

  public void scheduleHourly() {
    System.schedule('Hourly Package Data Extract Job', '0 0 * * * ?', this);
  }

  public void execute(System.SchedulableContext context) {
    Database.executeBatch(this, BATCH_SIZE);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    this.currentSObjectName = this.sobjectNames.remove(0);
    return getQueryLocator(currentSObjectName);
  }

  public void execute(Database.BatchableContext context, List<Object> scope) {
    switch on this.currentSObjectName {
      when 'MetadataPackage' {
        List<MetadataPackageInfo> packages = (List<MetadataPackageInfo>) JSON.deserialize(
          JSON.serialize(scope),
          List<MetadataPackageInfo>.class
        );
        this.processPackages(packages);
      }
      when 'MetadataPackageVersion' {
        List<MetadataPackageVersionInfo> packageVersions = (List<MetadataPackageVersionInfo>) JSON.deserialize(
          JSON.serialize(scope),
          List<MetadataPackageVersionInfo>.class
        );
        this.processPackageVersions(packageVersions);
      }
      when 'PackageSubscriber' {
        List<PackageSubscriberInfo> packageSubscribers = (List<PackageSubscriberInfo>) JSON.deserialize(
          JSON.serialize(scope),
          List<PackageSubscriberInfo>.class
        );
        this.processPackageSubscribers(packageSubscribers);
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

    // A horrible hack - when the 3 SObjects (above) don't exist in the org, the start() method fails,
    // and scratch orgs (used to create the 2GP) will never have the 3 SObjects. Overriding the query string
    // lets the platform "work", and unit tests check the value of this.query as a workaround
    this.currentQuery = query;
    if (Test.isRunningTest() == true && IS_DEV_HUB == false) {
      query = 'SELECT Id FROM User';
    }
    return Database.getQueryLocator(query);
  }

  private Database.DmlOptions getDmlOptions() {
    Database.DMLOptions dmo = new Database.dmlOptions();
    dmo.AllowFieldTruncation = true;
    return dmo;
  }

  private void processPackages(List<MetadataPackageInfo> metadataPackages) {
    List<Package__c> storedPackages = new List<Package__c>();
    for (MetadataPackageInfo metadataPackage : metadataPackages) {
      Package__c storedPackage = new Package__c(
        LastUpdated__c = metadataPackage.SystemModStamp,
        PackageCategory__c = metadataPackage.PackageCategory,
        PackageId__c = metadataPackage.Id,
        Name = metadataPackage.Name,
        NamespacePrefix__c = metadataPackage.NamespacePrefix
      );
      storedPackage.setOptions(getDmlOptions());
      storedPackages.add(storedPackage);
    }
    upsert storedPackages PackageId__c;
  }

  private void processPackageVersions(List<MetadataPackageVersionInfo> metadataPackageVersions) {
    List<PackageVersion__c> storedPackageVersions = new List<PackageVersion__c>();
    for (MetadataPackageVersionInfo metadataPackageVersion : metadataPackageVersions) {
      PackageVersion__c storedPackageVersion = new PackageVersion__c(
        BuildNumber__c = metadataPackageVersion.BuildNumber,
        IsDeprecated__c = metadataPackageVersion.IsDeprecated,
        LastUpdated__c = metadataPackageVersion.SystemModStamp,
        MajorVersion__c = metadataPackageVersion.MajorVersion,
        MinorVersion__c = metadataPackageVersion.MinorVersion,
        Name = metadataPackageVersion.Name,
        Package__r = new Package__c(PackageId__c = metadataPackageVersion.MetadataPackageId),
        PatchVersion__c = metadataPackageVersion.PatchVersion,
        ReleaseState__c = metadataPackageVersion.ReleaseState,
        SubscriberPackageVersionId__c = metadataPackageVersion.Id
      );
      storedPackageVersion.setOptions(getDmlOptions());
      storedPackageVersions.add(storedPackageVersion);
    }
    upsert storedPackageVersions SubscriberPackageVersionId__c;
  }

  private void processPackageSubscribers(List<PackageSubscriberInfo> packageSubscribers) {
    Map<String, PackageSubscriberOrg__c> parentSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();
    Map<String, PackageSubscriberOrg__c> childSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();

    for (PackageSubscriberInfo packageSubscriber : packageSubscribers) {
      PackageSubscriberOrg__c storedOrg = new PackageSubscriberOrg__c(
        InstalledStatus__c = packageSubscriber.InstalledStatus,
        InstanceName__c = packageSubscriber.InstanceName,
        LastUpdated__c = packageSubscriber.SystemModStamp,
        Name = packageSubscriber.OrgName,
        OrgId__c = packageSubscriber.OrgKey,
        OrgStatus__c = packageSubscriber.OrgStatus,
        OrgType__c = packageSubscriber.OrgType,
        PackageSubscriberId__c = packageSubscriber.Id,
        PackageVersion__r = new PackageVersion__c(
          SubscriberPackageVersionId__c = packageSubscriber.MetadataPackageVersionId
        )
      );
      if (packageSubscriber.ParentOrg == null) {
        parentSubscriberOrgsByOrgId.put(storedOrg.OrgId__c, storedOrg);
      } else {
        storedOrg.ParentOrgId__c = packageSubscriber.ParentOrg;
        childSubscriberOrgsByOrgId.put(storedOrg.OrgId__c, storedOrg);
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

  // Inner classes used to substitue the SObjects `MetadataPackage`, `MetadataPackageVersion`, and `PackageSubscriber`
  // that don't/won't/can't exist in scratch orgs (used for creating package versions)
  public class MetadataPackageInfo {
    public Id Id;
    public String Name;
    public String NamespacePrefix;
    public String PackageCategory;
    public Datetime SystemModStamp;
  }

  public class MetadataPackageVersionInfo {
    public Decimal BuildNumber;
    public Id Id;
    public Boolean IsDeprecated;
    public Decimal MajorVersion;
    public String MetadataPackageId;
    public Decimal MinorVersion;
    public String Name;
    public Decimal PatchVersion;
    public String ReleaseState;
    public Datetime SystemModStamp;
  }

  public class PackageSubscriberInfo {
    public Id Id;
    public String InstalledStatus;
    public String InstanceName;
    public Id MetadataPackageVersionId;
    public Id OrgKey;
    public String OrgName;
    public String OrgStatus;
    public String OrgType;
    public Id ParentOrg;
    public Datetime SystemModStamp;
  }
}
