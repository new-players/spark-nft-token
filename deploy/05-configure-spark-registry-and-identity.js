const { isAddress } = require("ethers");
const { ethers, network } = require("hardhat");
const fs = require("fs").promises;

module.exports = async ({ deployments }) => {
    const signers = await ethers.getSigners();
    const [deployer] = signers;

    const existingConfig = JSON.parse(await fs.readFile("config/deployment-config.json", "utf8"));

    const SparkIdentityInfo = existingConfig[network.name].SparkIdentity;
    const SparkRegistryInfo = existingConfig[network.name].SparkRegistry;
    const ERC6551ManagerInfo = existingConfig[network.name].ERC6551Manager;

    const { log } = deployments;

    const SparkRegistry = await ethers.getContractAt("SparkRegistry", SparkRegistryInfo.contractAddress, deployer);
    const SparkIdentity = await ethers.getContractAt("SparkIdentity", SparkIdentityInfo.contractAddress, deployer);

    const waitConfirmation = network.config.chainId === 31337 ? 0 : 6;

    const minterRole = await SparkIdentity.MINTER_ROLE();
    const grantMinterRoleTx = await SparkIdentity.grantRole(minterRole, SparkRegistryInfo.contractAddress);
    await grantMinterRoleTx.wait(waitConfirmation);

    log("Spark Identity minter role is granted to spark registry contract");

    if (SparkIdentityInfo.baseUri && SparkIdentityInfo.baseUri.length > 0) {
        const baseUriTx = await SparkIdentity.setBaseURI(SparkIdentityInfo.baseUri);
        await baseUriTx.wait(waitConfirmation);

        log("Spark Identity base uri is configured to: ", SparkIdentityInfo.baseUri);
    }

    if (ERC6551ManagerInfo.contractAddress && isAddress(ERC6551ManagerInfo.contractAddress)) {
        const erc6551ManagerTx = await SparkRegistry.configureERC6551Manager(ERC6551ManagerInfo.contractAddress);
        await erc6551ManagerTx.wait(waitConfirmation);
    
        log("Spark Registry (ERC6551 manager) is configured to: ", ERC6551ManagerInfo.contractAddress);
    }

    if (SparkRegistryInfo.isPaymentEnabled) {
        const nativePaymentAmountInWei = ethers.parseEther(SparkRegistryInfo.nativePaymentAmountInEther);

        if (nativePaymentAmountInWei > 0) {
            const nativePaymentTx = await SparkRegistry
                .configurePayment(SparkRegistryInfo.beneficiaryAddress, SparkRegistryInfo.isPaymentEnabled, nativePaymentAmountInWei);
            await nativePaymentTx.wait(waitConfirmation);
    
            log("Spark Registry payment is configured with these options: ", JSON.stringify({
                beneficiaryAddress: SparkRegistryInfo.beneficiaryAddress,
                isPaymentEnabled: SparkRegistryInfo.isPaymentEnabled,
                nativePaymentAmount: SparkRegistryInfo.nativePaymentAmountInEther
            }));
        }
    
        if (SparkRegistryInfo.paymentTokens.length > 0) {
            const filteredTokenInfo = SparkRegistryInfo.paymentTokens.filter(token => ethers.parseEther(token.amountInEther) > 0);
    
            const payTokenTx = await SparkRegistry.addPaymentTokens(
                filteredTokenInfo.map((token) => token.tokenAddress),
                filteredTokenInfo.map((token) => ethers.parseEther(token.amountInEther)),
                filteredTokenInfo.map((token) => token.status)
            );
            await payTokenTx.wait(waitConfirmation);
    
            log("Spark Registry payment tokens are configured with these options: ", JSON.stringify({
                tokenAddress: filteredTokenInfo.map((token) => token.tokenAddress),
                amount: filteredTokenInfo.map((token) => token.amountInEther),
                status: filteredTokenInfo.map((token) => token.status)
            }));
        }
    }

    if (SparkRegistryInfo.isRewardsEnabled) {
        const maxRewardsPerUserInWei = ethers.parseEther(SparkRegistryInfo.maxRewardsPerUserInEther);
        const rewardsPerMintInWei = ethers.parseEther(SparkRegistryInfo.rewardsPerMintInEther);
    
        if (maxRewardsPerUserInWei > 0 && rewardsPerMintInWei > 0) {
            if (rewardsPerMintInWei <= maxRewardsPerUserInWei) {
                const rewardConfigTx = await SparkRegistry
                    .configureRewards(rewardsPerMintInWei, maxRewardsPerUserInWei, SparkRegistryInfo.isRewardsEnabled);
                await rewardConfigTx.wait(waitConfirmation);
    
                log("Spark Registry rewards are configured with these options: ", JSON.stringify({
                    rewardsPerMint: SparkRegistryInfo.rewardsPerMintInEther,
                    maxRewardsPerUser: SparkRegistryInfo.maxRewardsPerUserInEther,
                    isRewardsEnabled: SparkRegistryInfo.isRewardsEnabled
                }));
            } else {
                log("rewardsPerMint > maxRewardsPerUser is not allowed");
            }
        }
    
        if (SparkRegistryInfo.rewardableNfts.length > 0) {
            const nftTokenWhitelistTx = await SparkRegistry.whitelistNftsForRewards(
                SparkRegistryInfo.rewardableNfts.map((nft) => nft.nftAddress),
                SparkRegistryInfo.rewardableNfts.map((nft) => nft.status)
            );
            await nftTokenWhitelistTx.wait(waitConfirmation);
    
            log("Spark Registry rewardable nfts are configured with these options: ", JSON.stringify({
                nftAddress: SparkRegistryInfo.rewardableNfts.map((nft) => nft.nftAddress),
                status: SparkRegistryInfo.rewardableNfts.map((nft) => nft.status)
            }));
        }   
    }
}

module.exports.tags = ["SparkConfiguration", "all", "local", "goerli", "sepolia", "fuji", "baseSepolia", "baseGoerli", "optimisticSepolia", "polygon", "ethereum", "avalanche", "base", "optimisticEthereum"];
