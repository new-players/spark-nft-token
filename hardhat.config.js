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
    }
}

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const FACTORY_DEPLOYER_PRIVATE_KEY = process.env.FACTORY_DEPLOYER_PRIVATE_KEY;

if (String(PRIVATE_KEY).toLowerCase() === String(FACTORY_DEPLOYER_PRIVATE_KEY).toLowerCase()) {
    throw new Error("Factory deployer and deployer should not be same");
}

const FORKING_BLOCK_NUMBER = parseInt(process.env.FORKING_BLOCK_NUMBER) || 0;
const REPORT_GAS = process.env.REPORT_GAS || false;

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL;
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
const FUJI_RPC_URL = process.env.FUJI_RPC_URL;
const BASE_SEPOLIA_RPC_URL = process.env.BASE_SEPOLIA_RPC_URL;
const BASE_GOERLI_RPC_URL = process.env.BASE_GOERLI_RPC_URL;

const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL;
const ETHEREUM_RPC_URL = process.env.ETHEREUM_RPC_URL;
const AVALANCHE_RPC_URL = process.env.AVALANCHE_RPC_URL;
const BASE_RPC_URL = process.env.BASE_RPC_URL;

const GOERLI_DEPLOYMENT_SETTINGS = {
    url: GOERLI_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 5
};

const SEPOLIA_DEPLOYMENT_SETTINGS = {
    url: SEPOLIA_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 11155111,
}

const FUJI_DEPLOYMENT_SETTINGS = {
    url: FUJI_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 43113
};

const BASE_SEPOLIA_DEPLOYMENT_SETTINGS = {
    url: BASE_SEPOLIA_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 84532,
}

const BASE_GOERLI_DEPLOYMENT_SETTINGS = {
    url: BASE_GOERLI_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 84531,
}


const POLYGON_DEPLOYMENT_SETTINGS = {
    url: POLYGON_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 137
};

const ETHEREUM_DEPLOYMENT_SETTINGS = {
    url: ETHEREUM_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 1
};

const AVALANCHE_DEPLOYMENT_SETTINGS = {
    url: AVALANCHE_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 43114
};

const BASE_DEPLOYMENT_SETTINGS = {
    url: BASE_RPC_URL,
    accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
    chainId: 8453,
}

const POLYGONSCAN_API_KEY = process.env.POLYGONSCAN_API_KEY;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const AVALANCHE_API_KEY = process.env.AVALANCHE_API_KEY;
const BASE_API_KEY = process.env.BASE_API_KEY;

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
            // uncomment when forking is required
            // forking: {
            //     url: GOERLI_RPC_URL,
            //     accounts: PRIVATE_KEY && FACTORY_DEPLOYER_PRIVATE_KEY ? [PRIVATE_KEY, FACTORY_DEPLOYER_PRIVATE_KEY] : [],
            //     blockNumber: FORKING_BLOCK_NUMBER
            // }
        },
        localhost: {
            chainId: 31337,
        },
        goerli: GOERLI_DEPLOYMENT_SETTINGS,
        sepolia: SEPOLIA_DEPLOYMENT_SETTINGS,
        fuji: FUJI_DEPLOYMENT_SETTINGS,
        baseSepolia: BASE_SEPOLIA_DEPLOYMENT_SETTINGS,
        baseGoerli: BASE_GOERLI_DEPLOYMENT_SETTINGS,
        polygon: POLYGON_DEPLOYMENT_SETTINGS,
        ethereum: ETHEREUM_DEPLOYMENT_SETTINGS,
        avalanche: AVALANCHE_DEPLOYMENT_SETTINGS,
        base: BASE_DEPLOYMENT_SETTINGS
    },
    defaultNetwork: "hardhat",
    etherscan: {
        apiKey: {
            goerli: ETHERSCAN_API_KEY,
            sepolia: ETHERSCAN_API_KEY,
            avalancheFujiTestnet: AVALANCHE_API_KEY,
            baseGoerli: BASE_API_KEY,
            mainnet: ETHERSCAN_API_KEY,
            polygon: POLYGONSCAN_API_KEY,
            avalanche: AVALANCHE_API_KEY,
            base: BASE_API_KEY
        },
        customChains: [
            {
                network: "baseSepolia",
                chainId: 84532,
                urls: {
                  apiURL: "https://api-sepolia.basescan.org/api",
                  browserURL: "https://sepolia.basescan.org"
                }
            }
        ]
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
            31337: 0,
            5: 0,
            11155111: 0,
            137: 0,
            1: 0,
            43114: 0,
            43113: 0,
            8453: 0,
            84532: 0,
            84531: 0
        },
        factoryDeployer: {
            31337: 1,
            5: 1,
            11155111: 1,
            137: 1,
            1: 1,
            43114: 1,
            43113: 1,
            8453: 1,
            84532: 1,
            84531: 1
        }
    },
    mocha: {
        timeout: 300000, // 300 seconds max for running tests
    },
};
