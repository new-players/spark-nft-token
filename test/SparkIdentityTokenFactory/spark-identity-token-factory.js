const { expect } = require("chai");
const { ethers, artifacts } = require("hardhat");

const ADMIN_ROLE_HASH = "0x0000000000000000000000000000000000000000000000000000000000000000";
const DEPLOYER_ROLE_HASH = "0xfc425f2263d0df187444b70e47283d622c70181c5baebb1306a01edba1ce184c";

let deployer;
let userOne;
let userTwo;
let factory;

describe('Spark Identity Token Factory', async () => {
    beforeEach(async () => {
        const signers = await ethers.getSigners();
        [deployer, userOne, userTwo] = signers;
        
        const SparkIdentityTokenFactoryFactory = await ethers.getContractFactory("SparkIdentityTokenFactory");
        const factoryTx = await SparkIdentityTokenFactoryFactory.deploy(deployer.address);    
        
        factory = await factoryTx.waitForDeployment();
    });

    it("Factory Deployment with zero address should fail", async () => {        
        const SparkIdentityTokenFactoryFactory = await ethers.getContractFactory("SparkIdentityTokenFactory");
        await expect(SparkIdentityTokenFactoryFactory.deploy(ethers.ZeroAddress)).to.be.revertedWithCustomError(SparkIdentityTokenFactoryFactory, 'ZeroAddressNotAllowed');
    })

    it("Factory Deployment should work with proper payloads", async () => {
        const signers = await ethers.getSigners();
        [deployer] = signers;
        
        const SparkIdentityTokenFactoryFactory = await ethers.getContractFactory("SparkIdentityTokenFactory");
        await expect(SparkIdentityTokenFactoryFactory.deploy(deployer.address)).not.to.be.reverted;        
    })

    it("Check roles and access controls for admin and deployer", async () => {
        const adminRole = await factory.DEFAULT_ADMIN_ROLE();
        const deployerRole =  await factory.DEPLOYER_ROLE();

        expect(adminRole).to.equal(ADMIN_ROLE_HASH);
        expect(deployerRole).to.equal(DEPLOYER_ROLE_HASH);

        await expect(await factory.hasRole(adminRole, deployer.address)).to.equal(true);
        await expect(await factory.hasRole(deployerRole, deployer.address)).to.equal(true);
    })

    it("Check a non admin user cannot grant or revoke roles", async () => {
        const adminRole = await factory.DEFAULT_ADMIN_ROLE();
        const deployerRole =  await factory.DEPLOYER_ROLE();

        await expect(factory.connect(userOne).grantRole(adminRole, userOne.address)).to.be.revertedWithCustomError(factory, 'AccessControlUnauthorizedAccount');
        await expect(factory.connect(userOne).grantRole(deployerRole, userOne.address)).to.be.revertedWithCustomError(factory, 'AccessControlUnauthorizedAccount');

        await expect(factory.connect(userOne).revokeRole(adminRole, userOne.address)).to.be.revertedWithCustomError(factory, 'AccessControlUnauthorizedAccount');
        await expect(factory.connect(userOne).revokeRole(deployerRole, userOne.address)).to.be.revertedWithCustomError(factory, 'AccessControlUnauthorizedAccount');
    })

    it("Check an admin can grant or revoke roles", async () => {
        const adminRole = await factory.DEFAULT_ADMIN_ROLE();
        const deployerRole =  await factory.DEPLOYER_ROLE();

        await expect(factory.grantRole(adminRole, userOne.address)).not.to.be.reverted;
        await expect(factory.grantRole(deployerRole, userOne.address)).not.to.be.reverted;

        await expect(await factory.hasRole(adminRole, userOne.address)).to.equal(true);
        await expect(await factory.hasRole(deployerRole, userOne.address)).to.equal(true);
    })

    it("Check a new admin can grant or revoke another admin roles", async () => {
        const adminRole = await factory.DEFAULT_ADMIN_ROLE();
        const deployerRole =  await factory.DEPLOYER_ROLE();

        await expect(factory.grantRole(adminRole, userOne.address)).not.to.be.reverted;
        await expect(factory.grantRole(deployerRole, userOne.address)).not.to.be.reverted;

        await expect(await factory.hasRole(adminRole, userOne.address)).to.equal(true);
        await expect(await factory.hasRole(deployerRole, userOne.address)).to.equal(true);

        await expect(factory.connect(userOne).grantRole(adminRole, userTwo.address)).not.to.be.reverted;
        await expect(factory.connect(userOne).grantRole(deployerRole, userTwo.address)).not.to.be.reverted;

        await expect(factory.connect(userOne).revokeRole(adminRole, userTwo.address)).not.to.be.reverted;
        await expect(factory.connect(userOne).revokeRole(deployerRole, userTwo.address)).not.to.be.reverted;
    })

    it("Revert when a non deployer user attempts deploy a contract", async () => {
        const encoder = ethers.AbiCoder.defaultAbiCoder();
        
        const args = ['SparkIdentity', 'SPID', deployer.address];
        const { bytecode } = await artifacts.readArtifact('SparkIdentity');
        const encodedArgs = encoder.encode(['string', 'string', 'address'], args);
        const deployableBytecode = ethers.solidityPacked(['bytes', 'bytes'], [bytecode, encodedArgs]);

        const salt = encoder.encode(["address", "uint256"], [await deployer.getAddress(), 0]);
        const deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);

        await expect(factory.connect(userOne).determinsiticDeploy(0, deployableSalt, deployableBytecode)).to.be.revertedWithCustomError(factory, 'DeployerRoleMissing');
    })

    it("Revert when a invalid payload is used for the deployment", async () => {
        const encoder = ethers.AbiCoder.defaultAbiCoder();
        
        const args = ['', '', ethers.ZeroAddress];
        const { bytecode } = await artifacts.readArtifact('SparkIdentity');
        const encodedArgs = encoder.encode(['string', 'string', 'address'], args);
        const deployableBytecode = ethers.solidityPacked(['bytes', 'bytes'], [bytecode, encodedArgs]);

        const salt = encoder.encode(["address", "uint256"], [await deployer.getAddress(), 0]);
        const deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);

        await expect(factory.determinsiticDeploy(0, deployableSalt, deployableBytecode)).to.be.revertedWith('INITIALIZATION_FAILED');
    })

    it("Deploys a contract when proper roles and payload is available", async () => {
        const encoder = ethers.AbiCoder.defaultAbiCoder();

        const args = ['SparkIdentity', 'SPID', deployer.address];
        const { bytecode } = await artifacts.readArtifact('SparkIdentity');
        const encodedArgs = encoder.encode(['string', 'string', 'address'], args);
        const deployableBytecode = ethers.solidityPacked(['bytes', 'bytes'], [bytecode, encodedArgs]);

        let salt = encoder.encode(["address", "uint256"], [await deployer.getAddress(), 0]);
        let deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);

        await expect(factory.determinsiticDeploy(0, deployableSalt, deployableBytecode)).not.to.be.reverted;

        // If the deterministic contract is deployed properly, the salt cannot be reused.
        await expect(factory.determinsiticDeploy(0, deployableSalt, deployableBytecode)).to.be.revertedWith('DEPLOYMENT_FAILED');

        // Different contract should be able to deploy with new salt
        salt = encoder.encode(["address", "uint256"], [deployer.address, 1]);
        deployableSalt = ethers.solidityPackedKeccak256(["bytes"], [salt]);
        await expect(factory.determinsiticDeploy(0, deployableSalt, deployableBytecode)).not.to.be.reverted;
    })
})