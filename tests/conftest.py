import pytest
from script.deploy import deploy

@pytest.fixture
def vesting_system():
    return deploy()
