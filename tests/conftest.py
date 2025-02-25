import boa
import pytest

from eth_utils import from_wei, to_wei
from script import load_merkle_proofs

# vesting info: 31% TGE, 69% linear vesting over 3 months

ONE_DAY = 60 * 60 * 24
THIRTY_DAYS = ONE_DAY * 30
SIXTY_DAYS = ONE_DAY * 60
NINETY_DAYS = ONE_DAY * 90

# helper functions


def to_wei_ether(amount: int) -> int:
    return to_wei(amount, "ether")


def from_wei_ether(amount: int) -> int:
    return from_wei(amount, "ether")

import pytest
from script.deploy import deploy

@pytest.fixture
def vesting_system():
    return deploy()
