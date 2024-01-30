require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require("hardhat-deploy");
require("hardhat-contract-sizer");
require("@nomiclabs/hardhat-solhint");
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-interface-generator");

const COMPILER_SETTINGS = {
    optimizer: {
        enabled: true,
        runs: 200,
    },
};

const PRIVATE_KEY = process.env.PRIVATE_KEY;

const REPORT_GAS = process.env.REPORT_GAS || false;

const MUMBAI_RPC_URL = process.env.MUMBAI_RPC_URL;

const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;

const MUMBAI_DEPLOYMENT_SETTINGS = {
    url: MUMBAI_RPC_URL,
    accounts: PRIVATE_KEY ? [PRIVATE_KEY] : [],
    chainId: 80001,
};

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.20",
                settings: COMPILER_SETTINGS,
            },
        ],
    },
    networks: {
        hardhat: {
            chainId: 31337,
        },
        localhost: {
            chainId: 31337,
        },
        mumbai: MUMBAI_DEPLOYMENT_SETTINGS,
    },
    defaultNetwork: "hardhat",
    etherscan: {
        apiKey: {
            polygonMumbai: POLYGONSCAN_API_KEY,
        },
    },
    gasReporter: {
        enabled: REPORT_GAS,
        currency: "USD",
        outputFile: "gas-report.txt",
        noColors: true,
    },
    contractSizer: {
        runOnCompile: false,
    },
    paths: {
        sources: "./contracts",
        tests: "./test",
        cache: "./build/cache",
        artifacts: "./build/artifacts",
    },
    namedAccounts: {
        deployer: {
            default: 0,
            80001: 0,
        },
    },
    mocha: {
        timeout: 300000, // 300 seconds max for running tests
    },
};
