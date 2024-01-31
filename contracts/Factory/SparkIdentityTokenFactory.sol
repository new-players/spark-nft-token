// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "solmate/src/utils/CREATE3.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "../Helpers/Validator.sol";

/// @title SparkIdentityTokenFactory contract
/// @author Venkatesh
/// @notice This contract is used to manage the deployment of SparkIdentityToken contracts
/// @custom:security-contact rvenki666@gmail.com
contract SparkIdentityTokenFactory is AccessControlEnumerable {
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    error DeployerRoleMissing();
    error InvalidSalt();
    error InvalidBytecode();

    /// @notice Event emitted when a new SparkIdentityToken contract is deployed
    event SparkIdentityTokenContractDeployed(
        address indexed contractAddress,
        address indexed deployedBy
    );

    /// @notice Modifier to allow only deployer and admin roles to call a function
    modifier onlyDeployer() {
        if (
            !hasRole(DEPLOYER_ROLE, _msgSender()) &&
            !hasRole(DEFAULT_ADMIN_ROLE, _msgSender())
        ) {
            revert DeployerRoleMissing();
        }
        _;
    }

    /// @notice Constructor for the SparkIdentityTokenFactory contract
    /// @param _owner The owner of the contract
    constructor(address _owner) {
        Validator.checkForZeroAddress(_owner);

        _grantRole(DEFAULT_ADMIN_ROLE, _owner);
        _grantRole(DEPLOYER_ROLE, _owner);
    }

    /// @notice Deploys a new contract using CREATE3
    /// @param _amount The amount of ether to send with the contract
    /// @param _salt The salt value for the contract
    /// @param _bytecode The bytecode of the contract
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

        emit SparkIdentityTokenContractDeployed(deployedContractAddress, msg.sender);
    }

    /// @notice Computes the address of a contract deployed with CREATE3
    /// @param _salt The salt value used in the deployment
    /// @return contractAddress The address of the contract
    function computeAddress(
        bytes32 _salt
    ) external view returns (address contractAddress) {
        contractAddress = CREATE3.getDeployed(_salt);
    }
}
