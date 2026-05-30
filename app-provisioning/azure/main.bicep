param rgName string
param location string = 'eastus'
param storageAccountName string = 'dpoprod${uniqueString(resourceGroup().id)}'

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

resource sa 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {}
  dependsOn: [
    rg
  ]
}
