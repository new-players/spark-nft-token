const { ethers, network, artifacts } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments }) => {
    const signers = await ethers.getSigners();
    const [deployer] = signers;

    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const SparkIdentityInfo = existingConfig[network.name].SparkIdentity;
    const SparkRegistryFactoryInfo = existingConfig[network.name].SparkRegistryFactory;
    const SparkRegistryInfo = existingConfig[network.name].SparkRegistry;

    const { log } = deployments;

    const SparkRegistryFactory = await ethers
        .getContractAt("SparkRegistryFactory", SparkRegistryFactoryInfo.contractAddress, deployer);

    const encoder = ethers.AbiCoder.defaultAbiCoder();

    const args = [SparkIdentityInfo.contractAddress, SparkRegistryInfo.rewardTokenAddress, SparkRegistryInfo.beneficiaryAddress, SparkRegistryInfo.owner];

    const { bytecode } = await artifacts.readArtifact('SparkRegistry');
    // this is equivalent to abi.encode(args); in solidity
    const encodedArgs = encoder.encode(['address', 'address', 'address', 'address'], args);
    // Combine bytecode and encoded constructor arguments for deployment
    const deployableBytecode = ethers.solidityPacked(['bytes', 'bytes'], [bytecode, encodedArgs]);

    // Generate a unique salt for deterministic deployment
    // this is equivalent to abi.encode(args); in solidity
    // The salt should be same accros all the chains to get the same address
    // Contract cannot be deployed twice with the same salt
    const salt = encoder.encode(["address", "uint256"], [await deployer.getAddress(), 0]);
    // Hash the salt for use in deterministic deployment
    // this is equivalent to keccak256(abi.encode(args)); in solidity
    const deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);

    // derive the computed address. Address computation is based on the 
    // Temprory Proxy - bytecode, salt, deployer address and 0xff (prefix byte to prevent a collision with create opcode)
    // Implementation contract is attached to the proxy
    // Hence create3 is only dependent on the salt and deployer address
    const computedAddress = await SparkRegistryFactory.computeAddress(deployableSalt);
    console.log(`Deterministic computed address of SparkRegistry (${network.name}) is: ${computedAddress}`);

     // Deploy the contract deterministically with the computed salt and bytecode
    const tx = await SparkRegistryFactory.determinsiticDeploy(0, deployableSalt, deployableBytecode);

    const waitConfirmation = network.config.chainId === 31337 ? 0 : 15;

    // Wait for 15 block confirmation to prevent contract verification failure
    await tx.wait(waitConfirmation);

    log(`SparkRegistry (${network.name}) deployed to ${computedAddress}`);

    // Update the deployment configuration with the new contract address
    const config = {
        ...existingConfig,
        [network.name]: {
            ...existingConfig[network.name],
            SparkRegistry: {
                ...existingConfig[network.name]['SparkRegistry'],
                contractAddress: computedAddress,
            },
        },
    };

    await fs.writeFile("config/deployment-config.json", JSON.stringify(config), "utf8");

    // Verify the contract on Etherscan for networks other than localhost
    if (network.config.chainId !== 31337) {
        await hre.run("verify:verify", {
            address: computedAddress,
            constructorArguments: args,
        });
    }
}

module.exports.tags = ["SparkRegistry", "all", "local", "goerli", "sepolia", "fuji", "baseSepolia", "baseGoerli", "polygon", "ethereum", "avalanche", "base"];
