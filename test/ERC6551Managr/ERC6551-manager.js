const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const fs = require("fs").promises;
const { TokenboundClient } = require("@tokenbound/sdk");

const formatAddress = (address) => {
    return String(address).toLowerCase();
};

const ADMIN_ROLE_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";
let ERC6551Manager;
let deployer;
let userOne;
let userTwo;
let MockNFT;
let ERC6551Registry;
let ERC6551AccountProxy;
let ERC6551AccountImplementation;
let ERC6551Salt;

describe("ERC6551 Manager Unit Test Cases", () => {
    beforeEach(async () => {
        [deployer, userOne, userTwo] = await ethers.getSigners();

        const exisitingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

        const { registry, tokenboundAccountProxy, tokenboundAccountImplementation, salt } = exisitingConfig[network.name === 'hardhat' ? 'local' : network.name].ERC6551Manager;

        const abiCoder = new ethers.AbiCoder();

        ERC6551Registry = registry;
        ERC6551AccountProxy = tokenboundAccountProxy;
        ERC6551AccountImplementation = tokenboundAccountImplementation;
        ERC6551Salt = abiCoder.encode(['uint256'], [salt]);

        const ERC6551ManagerFactory = await ethers.getContractFactory("ERC6551Manager");
        const MockNFTFactory = await ethers.getContractFactory("MockNFT");

        const nftTx = await MockNFTFactory.deploy(deployer.address);
        MockNFT = await nftTx.waitForDeployment();

        const erc6551ManagerTx = await ERC6551ManagerFactory.deploy(ERC6551Registry, ERC6551AccountProxy, ERC6551AccountImplementation, ERC6551Salt, deployer.address);
        ERC6551Manager = await erc6551ManagerTx.waitForDeployment();
    });

    it("ERC6551 Manager Contract Deployment Check", async () => {
        await expect(await ERC6551Manager.getAddress()).not.equal(undefined);
        await expect(await MockNFT.getAddress()).not.equal(undefined);
    });

    it("ERC6551 Manager configuration check", async () => {
        await expect(formatAddress(await ERC6551Manager.erc6551RegistryAddress())).to.equal(
            formatAddress(ERC6551Registry)
        );
        await expect(formatAddress(await ERC6551Manager.erc6551ProxyAddress())).to.equal(
            formatAddress(ERC6551AccountProxy)
        );
        await expect(formatAddress(await ERC6551Manager.erc6551ImplementationAddress())).to.equal(
            formatAddress(ERC6551AccountImplementation)
        );
        await expect(await ERC6551Manager.erc6551Salt()).to.equal(ERC6551Salt);
    });

    it("Check roles and access controls for admin", async () => {
        const adminRole = await ERC6551Manager.DEFAULT_ADMIN_ROLE();

        expect(adminRole).to.equal(ADMIN_ROLE_HASH);

        await expect(await ERC6551Manager.hasRole(adminRole, deployer.address)).to.equal(true);
    })

    it("Check a non admin user cannot grant or revoke roles", async () => {
        const adminRole = await ERC6551Manager.DEFAULT_ADMIN_ROLE();

        await expect(ERC6551Manager.connect(userOne).grantRole(adminRole, userOne.address)).to.be.revertedWithCustomError(ERC6551Manager, 'AccessControlUnauthorizedAccount');
        await expect(ERC6551Manager.connect(userOne).revokeRole(adminRole, userOne.address)).to.be.revertedWithCustomError(ERC6551Manager, 'AccessControlUnauthorizedAccount');
    })

    it("Check an admin can grant or revoke roles", async () => {
        const adminRole = await ERC6551Manager.DEFAULT_ADMIN_ROLE();

        await expect(ERC6551Manager.grantRole(adminRole, userOne.address)).not.to.be.reverted;
        await expect(await ERC6551Manager.hasRole(adminRole, userOne.address)).to.equal(true);
    })

    it("Check a new admin can grant or revoke another admin roles", async () => {
        const adminRole = await ERC6551Manager.DEFAULT_ADMIN_ROLE();

        await expect(ERC6551Manager.grantRole(adminRole, userOne.address)).not.to.be.reverted;
        await expect(await ERC6551Manager.hasRole(adminRole, userOne.address)).to.equal(true);
        await expect(ERC6551Manager.connect(userOne).grantRole(adminRole, userTwo.address)).not.to.be.reverted;
        await expect(ERC6551Manager.connect(userOne).revokeRole(adminRole, userTwo.address)).not.to.be.reverted;
    })

    it("Non admin user should be prevented from calling the functions which requires admin role", async () => {
        await expect(ERC6551Manager.connect(userTwo).setupERC6551Registry(ethers.ZeroAddress)).to.be
            .reverted;
        await expect(ERC6551Manager.connect(userTwo).setupERC6551Proxy(ethers.ZeroAddress)).to.be
            .reverted;
        await expect(ERC6551Manager.connect(userTwo).setupERC6551Implementation(ethers.ZeroAddress))
            .to.be.reverted;
        await expect(ERC6551Manager.connect(userTwo).setupERC6551Salt(ERC6551Salt)).to.be.reverted;
    });

    // it("Configure ERC6551 implementation address", async () => {
    //     await expect(ERC6551Manager.setupERC6551Implementation(ethers.ZeroAddress)).to.be.reverted;
    //     await ERC6551Manager.setupERC6551Implementation(randomAddress);
    //     await expect(formatAddress(await ERC6551Manager.erc6551ImplementationAddress())).to.equal(
    //         formatAddress(randomAddress)
    //     );
    //     await ERC6551Manager.setupERC6551Implementation(ERC6551AccountImplementation);
    //     await expect(formatAddress(await ERC6551Manager.erc6551ImplementationAddress())).to.equal(
    //         formatAddress(ERC6551AccountImplementation)
    //     );
    // });

    // it("Configure ERC6551 registry address", async () => {
    //     await expect(ERC6551Manager.setupERC6551Registry(ethers.ZeroAddress)).to.be.reverted;
    //     await ERC6551Manager.setupERC6551Registry(randomAddress);
    //     await expect(formatAddress(await ERC6551Manager.erc6551RegistryAddress())).to.equal(
    //         formatAddress(randomAddress)
    //     );
    //     await ERC6551Manager.setupERC6551Registry(ERC6551Registry);
    //     await expect(formatAddress(await ERC6551Manager.erc6551RegistryAddress())).to.equal(
    //         formatAddress(ERC6551Registry)
    //     );
    // });

    // it("Configure ERC6551 salt", async () => {
    //     const abiCoder = new ethers.AbiCoder();

    //     await ERC6551Manager.setupERC6551Salt(abiCoder.encode(['uint256'], [1]));
    //     await expect(await ERC6551Manager.erc6551Salt()).to.equal(abiCoder.encode(['uint256'], [1]));
    //     await ERC6551Manager.setupERC6551Salt(ERC6551Salt);
    //     await expect(await ERC6551Manager.erc6551Salt()).to.equal(ERC6551Salt);
    // });

    // it("Mint Mock NFT", async () => {
    //     await MockNFT.safeMint(userOne);
    //     await expect(await MockNFT.balanceOf(userOne)).to.equal(1);

    //     await MockNFT.safeMint(userTwo);
    //     await expect(await MockNFT.balanceOf(userTwo)).to.equal(1);
    // });

    // it("Check Mock NFT tokenURI", async () => {
    //     await expect(await MockNFT.tokenURI(1)).to.equal(
    //         "https://arcadians.dev.outplay.games/v2/arcadians/1"
    //     );
    // });

    // it("Check token bound account for NFT", async () => {
    //     const tokenBoundAccount = await ERC6551Manager.getTokenBoundAccount(
    //         await MockNFT.getAddress(),
    //         1
    //     );
    //     expect(tokenBoundAccount).not.to.equal(undefined);
    // });

    // It is not working in local network.
    // it("Deploy token bound account for a NFT", async () => {
    //     const tokenBoundAccount = await ERC6551Manager.getTokenBoundAccount(
    //         await MockNFT.getAddress(),
    //         1
    //     );

    //     const tokenboundClient = new TokenboundClient({
    //         signer: deployer,
    //         chainId: 5
    //     });

    //     const { account, txHash } = await tokenboundClient.createAccount({
    //         tokenContract: await MockNFT.getAddress(),
    //         tokenId: 1
    //     });

    //     expect(tokenBoundAccount).to.equal(account);
    // });

    // It is not working in local network.
    // it("Check NFT token bound account validity", async (done) => {
    //     const tokenBoundAccount = await ERC6551Manager.getTokenBoundAccount(await MockNFT.getAddress(), 1);

    //     const tokenboundClient = new TokenboundClient({ signer: deployer, chainId: network.config.chainId });

    //     console.log(tokenBoundAccount);

    //     const isAccountDeployed = await tokenboundClient.checkAccountDeployment({
    //         accountAddress: tokenBoundAccount,
    //     })

    //     console.log(isAccountDeployed)
    // })
});
