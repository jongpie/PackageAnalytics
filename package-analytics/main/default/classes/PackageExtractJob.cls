public without sharing class PackageExtractJob implements Database.Batchable<SObject>, Database.Stateful, Schedulable {
  private List<Schema.SObjectType> sobjectTypes;
  private Schema.SObjectType currentSObjectType;

  public PackageExtractJob() {
    this.sobjectTypes = new List<Schema.SObjectType>{
      Schema.MetadataPackage.SObjectType,
      Schema.MetadataPackageVersion.SObjectType,
      Schema.PackageSubscriber.SObjectType
    };
  }

  public void scheduleHourly() {
    System.schedule('Hourly Package Extract Job', '0 0 * * * ?', this);
  }

  public void execute(System.SchedulableContext context) {
    Database.executeBatch(this);
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    this.currentSObjectType = this.sobjectTypes.remove(0);
    return getQueryLocator(this.currentSObjectType);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    if (this.currentSObjectType == Schema.MetadataPackage.SObjectType) {
      this.processPackages(scope);
    } else if (this.currentSObjectType == Schema.MetadataPackageVersion.SObjectType) {
      this.processPackageVersions(scope);
    } else if (this.currentSObjectType == Schema.PackageSubscriber.SObjectType) {
      this.processPackageSubscribers(scope);
    }
  }

  public void finish(Database.BatchableContext context) {
    if (this.sobjectTypes.isEmpty() == false) {
      Database.executeBatch(this);
    }
  }

  private Database.QueryLocator getQueryLocator(Schema.SObjectType sobjectType) {
    if (sobjectType == Schema.MetadataPackage.SObjectType) {
      return Database.getQueryLocator(
        [SELECT Id, Name, NamespacePrefix, PackageCategory, SystemModStamp FROM MetadataPackage]
      );
    } else if (sobjectType == Schema.MetadataPackageVersion.SObjectType) {
      return Database.getQueryLocator(
        [
          SELECT
            BuildNumber,
            IsDeprecated,
            MajorVersion,
            MinorVersion,
            Name,
            MetadataPackageId,
            PatchVersion,
            ReleaseState,
            Id,
            SystemModStamp
          FROM MetadataPackageVersion
        ]
      );
    } else if (sobjectType == Schema.PackageSubscriber.SObjectType) {
      return Database.getQueryLocator(
        [
          SELECT
            Id,
            InstalledStatus,
            InstanceName,
            ParentOrg,
            MetadataPackageId,
            MetadataPackageVersionId,
            OrgKey,
            OrgName,
            OrgStatus,
            OrgType,
            SystemModStamp
          FROM PackageSubscriber
        ]
      );
    } else {
      return null;
    }
  }

  private void processPackages(List<MetadataPackage> metadataPackages) {
    List<Package__c> packages = new List<Package__c>();
    for (MetadataPackage metadataPackage : metadataPackages) {
      packages.add(
        new Package__c(
          LastUpdated__c = metadataPackage.SystemModStamp,
          PackageCategory__c = metadataPackage.PackageCategory,
          PackageId__c = Id.valueOf(metadataPackage.Id),
          Name = metadataPackage.Name,
          NamespacePrefix__c = metadataPackage.NamespacePrefix
        )
      );
    }
    upsert packages PackageId__c;
  }

  private void processPackageVersions(List<MetadataPackageVersion> metadataPackageVersions) {
    List<PackageVersion__c> packageVersions = new List<PackageVersion__c>();
    for (MetadataPackageVersion metadataPackageVersion : metadataPackageVersions) {
      packageVersions.add(
        new PackageVersion__c(
          BuildNumber__c = metadataPackageVersion.BuildNumber,
          IsDeprecated__c = metadataPackageVersion.IsDeprecated,
          LastUpdated__c = metadataPackageVersion.SystemModStamp,
          MajorVersion__c = metadataPackageVersion.MajorVersion,
          MinorVersion__c = metadataPackageVersion.MinorVersion,
          Name = metadataPackageVersion.Name,
          Package__r = new Package__c(PackageId__c = Id.valueOf(metadataPackageVersion.MetadataPackageId)),
          PatchVersion__c = metadataPackageVersion.PatchVersion,
          ReleaseState__c = metadataPackageVersion.ReleaseState,
          SubscriberPackageVersionId__c = Id.valueOf(metadataPackageVersion.Id)
        )
      );
    }
    upsert packageVersions SubscriberPackageVersionId__c;
  }

  private void processPackageSubscribers(List<PackageSubscriber> packageSubscribers) {
    Map<String, PackageSubscriberOrg__c> parentSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();
    Map<String, PackageSubscriberOrg__c> childSubscriberOrgsByOrgId = new Map<String, PackageSubscriberOrg__c>();

    for (PackageSubscriber packageSubscriber : packageSubscribers) {
      PackageSubscriberOrg__c org = new PackageSubscriberOrg__c(
        InstalledStatus__c = packageSubscriber.InstalledStatus,
        InstanceName__c = packageSubscriber.InstanceName,
        LastUpdated__c = packageSubscriber.SystemModStamp,
        Name = packageSubscriber.OrgName,
        OrgId__c = Id.valueOf(packageSubscriber.OrgKey),
        OrgStatus__c = packageSubscriber.OrgStatus,
        OrgType__c = packageSubscriber.OrgType,
        PackageSubscriberId__c = Id.valueOf(packageSubscriber.Id),
        PackageVersion__r = new PackageVersion__c(
          SubscriberPackageVersionId__c = Id.valueOf(packageSubscriber.MetadataPackageVersionId)
        )
      );
      if (packageSubscriber.ParentOrg == null) {
        parentSubscriberOrgsByOrgId.put(org.OrgId__c, org);
      } else {
        org.ParentOrgId__c = Id.valueOf(packageSubscriber.ParentOrg);
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
}
