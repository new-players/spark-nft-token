const { ethers, network } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments, getNamedAccounts }) => {
    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const { owner } = existingConfig[network.name].SparkRegistryFactory;

    const { deploy, log } = deployments;

    const { factoryDeployer } = await getNamedAccounts();

    const args = [owner];

    const SparkRegistryFactory = await deploy("SparkRegistryFactory", {
        from: factoryDeployer,
        args,
        automine: true,
        log: true,
        waitConfirmations: network.config.chainId === 31337 ? 0 : 6
    });

    log(`SparkRegistryFactory (${network.name}) deployed to ${SparkRegistryFactory.address}`);

    const config = {
        ...existingConfig,
        [network.name]: {
            ...existingConfig[network.name],
            SparkRegistryFactory: {
                ...existingConfig[network.name]['SparkRegistryFactory'],
                contractAddress: SparkRegistryFactory.address,
            },
        },
    };

    await fs.writeFile("config/deployment-config.json", JSON.stringify(config, null, 4), "utf8");

    // Verify the contract on Etherscan for networks other than localhost
    if (network.config.chainId !== 31337) {
        await hre.run("verify:verify", {
            address: SparkRegistryFactory.address,
            constructorArguments: args,
        });
    }
}

module.exports.tags = ["SparkRegistryFactory", "all", "local", "mumbai", "sepolia", "goerli", "fuji", "polygon", "ethereum", "avalanche"];
