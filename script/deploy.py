import boa

from src import VestedAirdrop, Token
from moccasin.boa_tools import VyperContract

# from datetime import datetime
from script import load_merkle_proofs


def deploy() -> VyperContract:
    current_time = int(boa.env.evm.patch.timestamp)
    token: VyperContract = Token.deploy()
    merkle_proofs = load_merkle_proofs()
    airdrop: VyperContract = VestedAirdrop.deploy(
        # merkle_root: bytes32,
        bytes.fromhex(merkle_proofs["root"][2:]),
        # token: address
        token,
        # vesting_start_time: uint256,
        current_time,
        # vesting_end_time: uint256,
        current_time + 60 * 60 * 24 * 30 * 3,  # 3 months
    )
    # send 100k tokens to airdrop contract
    token.transfer(airdrop, 100_000 * 10**18)
    return (token, airdrop)


def moccasin_main() -> VyperContract:
    return deploy()
