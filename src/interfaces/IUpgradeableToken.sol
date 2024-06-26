// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

interface IUpgradeableToken {
    function updateAggregator(address newAggregator) external;
    function emergencyBurn(address burnee, uint256 amount) external;
    function upgradeToAndCall(address newImpl, bytes memory param) external;
}