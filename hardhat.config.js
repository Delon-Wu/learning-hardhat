// hardhat.config.js
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-deploy");

module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    sepolia: {
      url: "https://sepolia.infura.io/v3/$1",
      accounts: ["$2"],
    },
  },
  etherscan: {
    apiKey: "YOUR_ETHERSCAN_API_KEY",
  },
  // 命名账户配置
  namedAccounts: {
    deployer: {
      default: 0, // 默认使用第一个账户
      localhost: 0,
      sepolia: 0,
    },
    feeWallet: {
      default: 1, // 第二个账户作为手续费钱包
    },
  },
};
