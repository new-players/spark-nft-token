const { ethers, network } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments, getNamedAccounts }) => {
    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const { registry, tokenboundAccountProxy, tokenboundAccountImplementation, salt, owner } = existingConfig[network.name].ERC6551Manager;

    const { deploy, log } = deployments;

    const { deployer } = await getNamedAccounts();

    const encoder = new ethers.AbiCoder();

    const deployableSalt = encoder.encode(["uint256"], [salt]);

    const args = [registry, tokenboundAccountProxy, tokenboundAccountImplementation, deployableSalt, owner];

    const ERC6551Manager = await deploy("ERC6551Manager", {
        from: deployer,
        args,
        automine: true,
        log: true,
        waitConfirmations: network.config.chainId === 31337 ? 0 : 6
    });

    log(`ERC6551Manager (${network.name}) deployed to ${ERC6551Manager.address}`);

    const config = {
        ...existingConfig,
        [network.name]: {
            ...existingConfig[network.name],
            ERC6551Manager: {
                ...existingConfig[network.name]['ERC6551Manager'],
                contractAddress: ERC6551Manager.address,
            },
        },
    };

    await fs.writeFile("config/deployment-config.json", JSON.stringify(config, null, 4), "utf8");

    // Verify the contract on Etherscan for networks other than localhost
    if (network.config.chainId !== 31337) {
        await hre.run("verify:verify", {
            address: ERC6551Manager.address,
            constructorArguments: args,
        });
    }
}

module.exports.tags = ["ERC6551Manager", "all", "local", "mumbai", "sepolia", "goerli", "fuji", "polygon", "ethereum", "avalanche"];
