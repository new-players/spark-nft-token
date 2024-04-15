const { ethers, network } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments, getNamedAccounts }) => {
    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const { owner } = existingConfig[network.name].SparkIdentityTokenFactory;

    const { deploy, log } = deployments;

    const { factoryDeployer } = await getNamedAccounts();

    const args = [owner];

    const SparkIdentityTokenFactory = await deploy("SparkIdentityTokenFactory", {
        from: factoryDeployer,
        args,
        automine: true,
        log: true,
        waitConfirmations: network.config.chainId === 31337 ? 0 : 6,
    });

    log(
        `SparkIdentityTokenFactory (${network.name}) deployed to ${SparkIdentityTokenFactory.address}`
    );

    const config = {
        ...existingConfig,
        [network.name]: {
            ...existingConfig[network.name],
            SparkIdentityTokenFactory: {
                ...existingConfig[network.name]["SparkIdentityTokenFactory"],
                contractAddress: SparkIdentityTokenFactory.address,
            },
        },
    };

    await fs.writeFile("config/deployment-config.json", JSON.stringify(config), "utf8");

    // Verify the contract on Etherscan for networks other than localhost
    if (network.config.chainId !== 31337) {
        await hre.run("verify:verify", {
            address: SparkIdentityTokenFactory.address,
            constructorArguments: args,
        });
    }
};

module.exports.tags = [
    "SparkIdentityTokenFactory",
    "all",
    "local",
    "goerli",
    "sepolia",
    "fuji",
    "baseSepolia",
    "baseGoerli",
    "optimisticSepolia",
    "polygon",
    "ethereum",
    "avalanche",
    "base",
    "optimisticEthereum",
];
