# Package Analytics

Provides reportable data for your Salesforce packages in your dev hub.

[![Install Unlocked Package in a Dev Hub](./images/btn-install-unlocked-package-production.png)](https://login.salesforce.com/packaging/installPackage.apexp?p0=04t4x000000FEiRAAW)

## Getting Started

1. Install the package into your dev hub
2. Schedule the Apex job using `new PackageExtractJob().scheduleHourly();`
3. Optional: run the job ad hoc, using `Database.executeBatch(new PackageExtractJob(), 2000);`
4. Optional: assign the permission set 'Package Analytics Admin' to any users that should be able to see/report on the data. Admins should already have access & will not need to have the permission set.
5. Open the app 'Package Analytics' in App Switcher
6. Enjoy the reportable data about your packages. You can build your own reports & dashboards, using these custom objects
   - `Package__c`
   - `PackageVersion__c`
   - `PackageSubscriberOrg__c`
