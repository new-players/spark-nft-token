// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "solmate/src/utils/CREATE3.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "../Helpers/Validator.sol";

/// @title SparkRegistryFactory Contract
/// @notice This contract is used for deploying new SparkRegistry contracts deterministically using CREATE3
/// @dev Inherits AccessControlEnumerable for role-based permission management
/// @author Venkatesh
/// @custom:security-contact rvenki666@gmail.com
contract SparkRegistryFactory is AccessControlEnumerable {
    /// @dev Role identifier for deployers
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    /// @dev Custom error for missing deployer role
    error DeployerRoleMissing();
    /// @dev Custom error for invalid salt input
    error InvalidSalt();
    /// @dev Custom error for invalid bytecode input
    error InvalidBytecode();

    /// @notice Emitted when a new SparkRegistry contract is deployed
    /// @param contractAddress The address of the deployed contract
    /// @param deployedBy The address of the deployer
    event SparkRegistryContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy
    );

    /// @notice Modifier to restrict function access to deployers and admins
    modifier onlyDeployer() {
        if (
            !hasRole(DEPLOYER_ROLE, _msgSender()) &&
            !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())
        ) {
            revert DeployerRoleMissing();
        }
        _;
    }

    /// @notice Constructor to set up the contract with initial roles
    /// @param _owner The address to be granted admin and deployer roles
    constructor(address _owner) {
        Validator.checkForZeroAddress(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(DEPLOYER_ROLE, _owner);
    }

    /// @notice Deploys a new SparkRegistry contract using CREATE3
    /// @dev Emits a SparkRegistryContractDeployed event upon successful deployment
    /// @param _amount The amount of ether to send with the contract creation
    /// @param _salt The salt to use for deterministic deployment
    /// @param _bytecode The bytecode of the contract to deploy
    /// @return deployedContractAddress The address of the deployed contract
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

        emit SparkRegistryContractDeployed(deployedContractAddress, msg.sender);
    }

    /// @notice Computes the address of a contract deployed with a specific salt via CREATE3
    /// @param _salt The salt used during deployment
    /// @return contractAddress The address of the contract deployed with the given salt
    function computeAddress(
        bytes32 _salt
    ) external view returns (address contractAddress) {
        contractAddress = CREATE3.getDeployed(_salt);
    }
}
