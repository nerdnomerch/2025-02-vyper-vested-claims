# @done-informative missing pragma here
# pragma version 0.4.0
"""
@title Vested Claims
@license MIT
@author Krakovia
@notice This contract is used to distribute tokens to users, 31% TGE, 69% linear vesting
"""

# @not-relevant from ethereum.ercs import IERC20
interface IERC20:
    def transfer(_to: address, _value: uint256) -> bool: nonpayable

# @done-gas following var should be immutable
vesting_start_time: public(uint256)
vesting_end_time:   public(uint256)
token:              public(address)
owner:              public(address)

claimed_amount:     public(HashMap[address, uint256])
merkle_root:        public(bytes32)


event Claimed:
    user:   indexed(address)
    amount: uint256
event MerkleRootUpdated:
    merkle_root: indexed(bytes32)
event TokensRescued:
    to:     indexed(address)
    amount: uint256

@deploy
def __init__(merkle_root: bytes32, token: address, vesting_start_time: uint256, vesting_end_time: uint256):
    """
    @notice Initialize the contract with the merkle root, token address, vesting start and end time
    @param merkle_root: bytes32, the merkle root of the vesting list
    @param token: address, the address of the token contract
    @param vesting_start_time: uint256, the start time of the vesting
    @param vesting_end_time: uint256, the end time of the vesting
    """
    self.merkle_root = merkle_root
    self.token = token
    self.vesting_start_time = vesting_start_time
    self.vesting_end_time = vesting_end_time
    # @done-informative using snekmate lib/pypi/snekmate/auth/ownable.vy __init__
    self.owner = msg.sender
    log MerkleRootUpdated(merkle_root)

# @done-informative using snekmate lib/pypi/snekmate/auth/ownable.vy _check_owner
def onlyOwner():
    """
    @notice This function is used to restrict access to the owner only
    """
    assert msg.sender == self.owner, "Only owner can call this function"

@pure
def _hash_pair(a: bytes32, b: bytes32) -> bytes32:
    """
    @notice This function is used to hash a pair of bytes32
    @param a: bytes32
    @param b: bytes32
    @return bytes32: the hash of the pair
    """
    if convert(a, uint256) < convert(b, uint256):
        return keccak256(concat(a, b))
    return keccak256(concat(b, a))

# @done-informative magic number 20 should be declared as constant for clarity
# @audit-question why 20?
def _verify_proof(proof: DynArray[bytes32, 20], leaf: bytes32) -> bool:
    """
    @notice This function is used to verify the merkle proof
    @param proof: DynArray[bytes32, 20], the merkle proof
    @param leaf: bytes32, the leaf node
    @return bool: True if the proof is valid
    """
    computed_hash: bytes32 = leaf
    for proof_element: bytes32 in proof:
        computed_hash = self._hash_pair(computed_hash, proof_element)
    return computed_hash == self.merkle_root

# @done-informative magic number 20 should be declared as constant for clarity
def verify_proof(user: address, amount: uint256, proof: DynArray[bytes32, 20]) -> bool:
    """
    @notice This function is used to verify the merkle proof
    @param user: address, the address of the user
    @param amount: uint256, the amount of tokens
    @param proof: DynArray[bytes32, 20], the merkle proof
    @return bool: True if the proof is valid
    """
    # @audit need tests with user 0 address
    return self._verify_proof(
        proof,
        keccak256(
            concat(
                convert(user, bytes20),
                convert(amount, bytes32)
            )
        )
    )

@view
def _calculate_vested_amount(total_amount: uint256) -> uint256:
    """
    @notice This function is used to calculate the vested amount
    @param total_amount: uint256, the total amount of tokens
    @return vested: uint256, the vested amount
    """
    # @audit Both the timestamp and the block hash can be influenced by miners to some degree. 
    # Bad actors in the mining community can for example run a casino payout function on a chosen hash and just retry a different 
    # hash if they did not receive any money.
    current_time: uint256 = block.timestamp
    start_time:   uint256 = self.vesting_start_time
    end_time:     uint256 = self.vesting_end_time
    vested:       uint256 = 0

    if current_time >= end_time:
        return total_amount

    vesting_duration: uint256 = end_time - start_time
    elapsed:          uint256 = current_time - start_time
    # @done-informative magic number 31 and 69 should be declared as constant for clarity
    # although they are declared in description of the contract
    # @done-informative magic number 100 should be declared as constant for clarity PRECISION
    instant_release:  uint256 = (total_amount * 31) // 100
    linear_vesting:   uint256 = (total_amount * 69) // 100

    vested = instant_release + (linear_vesting * elapsed) // vesting_duration
    return vested

@external
def set_merkle_root(merkle_root: bytes32):
    """
    @notice This function is used to set the merkle root
    @param merkle_root bytes32, the new merkle root
    @dev This function can only be called by the owner
    """
    # @done-informative using snekmate lib/pypi/snekmate/auth/ownable.vy _check_owner
    self.onlyOwner()
    self.merkle_root = merkle_root
    log MerkleRootUpdated(merkle_root)

@external
def rescue_tokens(to: address, amount: uint256):
    """
    @notice This function is used to rescue tokens from the contract
    @param to address, the address to send the tokens to
    @param amount uint256, the amount of tokens to send
    @dev this is a "better safe then sorry" function, use it only in case of emergency
    @dev This function can only be called by the owner
    """
    # @done-informative using snekmate lib/pypi/snekmate/auth/ownable.vy _check_owner
    self.onlyOwner()
    log TokensRescued(to, amount)
    _success: bool = extcall IERC20(self.token).transfer(to, amount)
    assert _success, "Transfer failed"


@external
def claim(user: address, total_amount: uint256, proof: DynArray[bytes32, 20]) -> bool:
    """
    @notice This function is used to claim the tokens
    @dev Anyone can claim for any user
    @param user address, the address of the user
    @param total_amount uint256, the total amount of tokens
    @param proof DynArray[bytes32, 20], the merkle proof
    @return bool True if the claim is successful
    """
    # @audit need tests with user 0 address
    # Checks
    # @audit check this part of the code with for loop amd no signature
    assert self.verify_proof(user, total_amount, proof), "Invalid proof"
    assert block.timestamp >= self.vesting_start_time, "Claiming is not available yet"

    claimable:      uint256 = 0
    current_amount: uint256 = self.claimed_amount[user]
    vested:         uint256 = self._calculate_vested_amount(total_amount)

    # Calculate how much the user can claim now
    if vested > current_amount:
        # @audit
        claimable = vested - current_amount

    assert claimable > 0, "Nothing to claim"
    # Update the claimed amount - Effects
    self.claimed_amount[user] += claimable
    # invariant: claimed amount should always be less than or equal to amount (better safe then sorry)
    assert current_amount + claimable <= total_amount, "Claimed amount exceeds total amount"
    log Claimed(user, claimable)
    
    # Transfer the claimable amount to the user - Interactions
    _success: bool = extcall IERC20(self.token).transfer(user, claimable)
    assert _success, "Transfer failed"
    return True

@view
@external
def claimable_amount(user: address, total_amount: uint256) -> uint256:
    """
    @notice this function is needed on the frontend to show the claimable amount
    @param user address, the address of the user
    @param total_amount uint256, the total amount of tokens
    @return claimable uint256, the amount of tokens that can be claimed
    @dev the data is NOT verified against the merkle root
    @dev no on-chain contract should/will use this function
    """
    # @audit need tests with user 0 address
    assert block.timestamp >= self.vesting_start_time, "Claiming is not available yet"

    claimable:      uint256 = 0
    current_amount: uint256 = self.claimed_amount[user]
    vested:         uint256 = self._calculate_vested_amount(total_amount)

    # Calculate how much the user can claim now
    if vested > current_amount:
        claimable = vested - current_amount

    return claimable
