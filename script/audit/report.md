## Informational

### [I-1] No pragma directives does not ensure version compatibility

**Description:** 

Pragma directive is missing in `VestedAirdrop.vy`,letting the contract to be compiled by any compiler version. To ensure version compatibility, it is recommended to add a pragma directive with a specific version.

**Recommended Mitigation:** 
```py
# pragma version 0.4.0
```


### [I-2] Avoid using magic numbers to enhance clarity and readability

**Description:** 

Magic numbers are used in the code to store constants, making the code less readable. It is recommended to use constants instead.

Here are the magic numbers used in the code:
```py
proof: DynArray[bytes32, 20] # why 20 is selected? max length?
# 31 and 69 are explained in the contract description
# but it could be more explicit as for 100 as the precision
instant_release:  uint256 = (total_amount * 31) // 100
linear_vesting:   uint256 = (total_amount * 69) // 100
```

**Recommended Mitigation:** 

Create proper constants with clear names can enhance readability:
```py
PRECISION: uint256 = 100
TGE_RELEASE_PERCENT: uint256 = 31 # Token Generation Event
LINEAR_VESTING_PERCENT: uint256 = 69
MAX_PROOF_LENGTH: uint256 = 20
```

## Gas

### [G-1] Store variables should be immutable to improve gas efficiency

**Description:** 
The following store variables are initialized in the constructor but not changed after that: 

```py
vesting_start_time: public(uint256)
vesting_end_time:   public(uint256)
token:              public(address)
owner:              public(address)
```

Immutables are not stored in the storage but as a part of the contract. So changing them to immutable could improve the gas efficiency.

**Recommended Mitigation:** 
```diff
- vesting_start_time: public(uint256)
- vesting_end_time:   public(uint256)
- token:              public(address)
- owner:              public(address)
+ VESTING_START_TIME: public(immutable(uint256))
+ VESTING_END_TIME:   public(immutable(uint256))
+ TOKEN:              public(immutable(address))
+ OWNER:              public(immutable(address))
```

## Low
### [L-1] Lacking of ownership transferability can lead to scalability issues

**Description:** 
Owner is trusted so this issue could be low or just informational. But `VestedAirdrop::rescue_tokens` and `VestedAirdrop::set_merkle_root` are dependent on the owner. Ownership is only set once during deployment of the contract and cannot be changed afterwards. As the protocol will evolve, this might be a problem in the future if different roles are assigned to different addresses, or the current owner changes for the protocol. If the owner is changed after deployment in the protocol, then this contract will not work as expected and we would need to deploy a new contract with the new owner.

**Recommended Mitigation:** 

Add the trusted `snekmate` dependency and use the `ownable` library to allow features like ownership transferability or checking the owner.

```bash
mox install snekmate
```

Import the `ownable` snekmate library:
```py
from snekmate.auth import ownable

initializes: ownable
```

It should add the following functions to the contract:
```py
@internal
# replacing the custom def onlyOwner():
def _check_owner():
    ...

def _transfer_ownership(new_owner: address):
    ...
```

Then export this specific external function:
```py
exports: (
    ownable.transfer_ownership
    # other if needed
)  
```

And invoke __init__ inside the constructor:
```py
def __init__():
    ownable.__init__()
```

## Medium

## High
