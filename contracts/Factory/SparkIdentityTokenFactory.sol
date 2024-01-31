// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "solmate/src/utils/CREATE3.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "../Helpers/Validator.sol";

contract SparkIdentityTokenFactory is AccessControlEnumerable {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    error DeployerRoleMissing();
    error InvalidSalt();
    error InvalidBytecode();

    event SparkIdentityTokenContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy
    );

    modifier onlyDeployer() {
        if (
            !hasRole(DEPLOYER_ROLE, _msgSender()) &&
            !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())
        ) {
            revert DeployerRoleMissing();
        }
        _;
    }

    constructor(address _owner) {
        Validator.checkForZeroAddress(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(DEPLOYER_ROLE, _owner);
    }

    function determinsiticDeploy(
        uint256 _amount,
        bytes32 _salt,
        bytes calldata _bytecode
    ) external onlyDeployer returns (address deployedContractAddress) {
        if (_salt.length == 0) {
            revert InvalidSalt();
        }

        if (_bytecode.length == 0) {
            revert InvalidBytecode();
        }

        deployedContractAddress = CREATE3.deploy(_salt, _bytecode, _amount);

        Validator.checkForZeroAddress(deployedContractAddress);

        emit SparkIdentityTokenContractDeployed(deployedContractAddress, msg.sender);
    }

    function computeAddress(
        bytes32 _salt
    ) external view returns (address contractAddress) {
        contractAddress = CREATE3.getDeployed(_salt);
    }
}
