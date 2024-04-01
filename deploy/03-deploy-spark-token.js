const { ethers, network, artifacts } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments }) => {
    const signers = await ethers.getSigners();
    const [deployer] = signers;

    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const { name, symbol, owner } = existingConfig[network.name].SparkIdentity;
    const { contractAddress } = existingConfig[network.name].SparkIdentityTokenFactory;

    const { log } = deployments;

    const SparkIdentityTokenFactory = await ethers.getContractAt("SparkIdentityTokenFactory", contractAddress, deployer);

    const encoder = ethers.AbiCoder.defaultAbiCoder();

    const args = [name, symbol, owner];

    const { bytecode } = await artifacts.readArtifact('SparkIdentity');
    // this is equivalent to abi.encode(args); in solidity
    const encodedArgs = encoder.encode(['string', 'string', 'address'], args);
    // Combine the bytecode and encoded arguments for deployment
    const deployableBytecode = ethers.solidityPacked(['bytes', 'bytes'], [bytecode, encodedArgs]);

    // Generate a unique salt based on deployer's address and a nonce
    // this is equivalent to abi.encode(args); in solidity
    // The salt should be same accros all the chains to get the same address
    // Contract cannot be deployed twice with the same salt
    const salt = encoder.encode(["address", "uint256"], [await deployer.getAddress(), 0]);
    // Hash the salt for use in deterministic deployment
    // this is equivalent to keccak256(abi.encode(args)); in solidity
    const deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);

    // Compute the address where the contract will be deployed
    // derive the computed address. Address computation is based on the 
    // Temprory Proxy - bytecode, salt, deployer address and 0xff (prefix byte to prevent a collision with create opcode)
    // Implementation contract is attached to the proxy
    // Hence create3 is only dependent on the salt and deployer address
    const computedAddress = await SparkIdentityTokenFactory.computeAddress(deployableSalt);
    console.log(`Deterministic computed address of SparkIdentity token (${network.name}) is: ${computedAddress}`);

    // Deploy the contract deterministically with the computed salt and bytecode
    const tx = await SparkIdentityTokenFactory.determinsiticDeploy(0, deployableSalt, deployableBytecode);
    
    const waitConfirmation = network.config.chainId === 31337 ? 0 : 15;

    // Wait for 15 block confirmation to prevent contract verification failure
    await tx.wait(waitConfirmation);

    log(`SparkIdentity (${network.name}) deployed to ${computedAddress}`);

    // Update the deployment configuration with the new contract address
    const config = {
        ...existingConfig,
        [network.name]: {
            ...existingConfig[network.name],
            SparkIdentity: {
                ...existingConfig[network.name]['SparkIdentity'],
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

module.exports.tags = ["SparkIdentity", "all", "local", "goerli", "sepolia", "fuji", "baseSepolia", "polygon", "ethereum", "avalanche", "base"];
