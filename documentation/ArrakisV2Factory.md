# ArrakisV2 Smart Factory Contract

### **Constant/Immutable Properties**

**version** : a string describing the version number of the current implementation. Each change on the ArrakisV2 Factory smart contract, like bug fixes should increment that number.

**arrakisV2Beacon** : contract who store the implementation of ArrakisV2 vault.

**deployer** : Official deployer of Arrakis Dao.

### **Public Properties**

**index** : keep track of the number of vault deployed.

### **Internal Properties**

**\_deployers** : set of deployer that have deployed a vault.
**\_vaults** : mapping of deployers and set of vaults deployed by them.

### _External Functions_

##### deployVault

**parameters** : 
- params\_ : struct containing settings of the vault that will be deployed.
- isBeacon\_ : if true the deployed vault will be through a beacon proxy. If false we will use a transparent proxy.

**effects** :
- sort tokens.
- get name of the vault that will be deployed.
- if isBeacon\_ is true deploy it through a beacon proxy, if false through a transparent proxy.
- add the vault on the list of vault deployed by the deployer.
- add the deployer on the deployer list if it's a new deployer.
- increment index.

**events** :
- VaultCreated : log new created vault address.

### _Public Functions_

### _Internal Functions_
