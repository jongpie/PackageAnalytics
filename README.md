# Package Analytics

Provides reportable data for your Salesforce packages in your dev hub.

[Install in a Sandbox](https://test.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000FEiRAAW)

## Getting Started

1. Deploy or install the package into your dev hub
2. Assign the permission set 'Package Analytics Admin' to your user.
3. Schedule the Apex job using `new PackageExtractJob().scheduleHourly();`
4. Optional: run the job ad hoc, using `Database.executeBatch(new PackageExtractJob(), 2000);`
5. Open the app 'Package Analytics' in App Switcher
6. Enjoy the reportable data about your packages. You can build your own reports & dashboards, using these custom objects
   - `Package__c`
   - `PackageVersion__c`
   - `PackageSubscriberOrg__c`
