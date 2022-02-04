// Data cleanup
List<Package__c> existingPackages = [SELECT Id FROM Package__c];
if (existingPackages.isEmpty() == false) {
  delete existingPackages;
  Database.emptyRecycleBin(existingPackages);
}
List<PackageVersion__c> existingPackageVersions = [SELECT Id FROM PackageVersion__c];
if (existingPackageVersions.isEmpty() == false) {
  delete existingPackageVersions;
  Database.emptyRecycleBin(existingPackageVersions);
}
List<PackageSubscriberOrg__c> existingPackageSubscriberOrgs = [SELECT Id FROM PackageSubscriberOrg__c];
if (existingPackageSubscriberOrgs.isEmpty() == false) {
  delete existingPackageSubscriberOrgs;
  Database.emptyRecycleBin(existingPackageSubscriberOrgs);
}

// Start data creation
List<String> fakePackageNames = new List<String>{
  'Another Package',
  'My 2GP Package',
  'Some Package',
  'What is this, another package?! Yes, yes it is.'
};
List<Package__c> packages = new List<Package__c>();
for (Integer i = 0; i < fakePackageNames.size(); i++) {
  String packageName = fakePackageNames.get(i);

  String namespacePrefix;
  if (i == 1) {
    namespacePrefix = 'abc';
  } else if (i == 3) {
    namespacePrefix = 'xyz';
  }

  packages.add(
    new Package__c(
      LastUpdated__c = System.now().addDays(-213 / (i + 3)).addMinutes(Integer.valueOf(-Math.random() * 100)),
      PackageCategory__c = 'Package2',
      PackageId__c = '0335Y000000Z' + i + 'NuQAO',
      Name = packageName,
      NamespacePrefix__c = namespacePrefix
    )
  );
}
insert packages;

Integer packageVersionsToCreate = 5;
List<PackageVersion__c> packageVersions = new List<PackageVersion__c>();
for (Integer z = 0; z < packages.size(); z++) {
  Package__c fakePackage = packages.get(z);

  for (Integer i = 0; i < packageVersionsToCreate; i++) {
    String releaseState = 'Beta';
    if (i == 3 || i == 4) {
      releaseState = 'Released';
    }

    Datetime lastUpdatedDatetime = System.now()
      .addDays(-213 / (i + 3))
      .addMinutes(Integer.valueOf(-Math.random() * 100))
      .addMinutes(Integer.valueOf(60 / (z + 3.75)));

    packageVersions.add(
      new PackageVersion__c(
        BuildNumber__c = i,
        IsDeprecated__c = i == 0 ? true : false,
        LastUpdated__c = lastUpdatedDatetime,
        MajorVersion__c = 1,
        MinorVersion__c = i,
        Name = 'Version ' + (i + 1),
        Package__c = fakePackage.Id,
        PatchVersion__c = 3,
        ReleaseState__c = releaseState,
        SubscriberPackageVersionId__c = '04t5Y0000' + z + i + '5lLzQAI'
      )
    );
  }
}
insert packageVersions;

Integer packageSubscriberOrgsToCreate = 20;
List<PackageSubscriberOrg__c> packageSubscriberOrgs = new List<PackageSubscriberOrg__c>();
for (Integer z = 0; z < packageVersions.size(); z++) {
  PackageVersion__c packageVersion = packageVersions.get(z);

  for (Integer i = 0; i < packageSubscriberOrgsToCreate; i++) {
    Datetime lastUpdatedDatetime = System.now()
      .addDays(-213 / (i + 3))
      .addMinutes(Integer.valueOf(-Math.random() * 100))
      .addMinutes(Integer.valueOf(60 / (z + 3.75)));
    String orgType = 'Sandbox';
    if (Math.mod(i, 3) == 0) {
      orgType = 'Production';
    }
    String orgStatus = 'Active';
    if (orgType == 'Sandbox') {
      orgStatus = Math.mod(i, 4) == 0 ? 'Trial' : 'Demo';
    }

    String orgId = ('00D0R0000' + z + String.valueOf(packageVersion.Id).substring(13, 16) + i + 'WddDUAS').left(18);
    String packageSubscriberId = ('0Hb0R000' + i + String.valueOf(packageVersion.Id).right(7) + z + 'SN6NSAW').left(18);

    packageSubscriberOrgs.add(
      new PackageSubscriberOrg__c(
        InstalledStatus__c = 'i',
        InstanceName__c = 'NA' + i,
        LastUpdated__c = lastUpdatedDatetime,
        Name = 'Some customer org',
        OrgId__c = orgId,
        OrgStatus__c = orgStatus,
        OrgType__c = orgType,
        PackageSubscriberId__c = packageSubscriberId,
        PackageVersion__c = packageVersion.Id
      )
    );
  }
}
insert packageSubscriberOrgs;
