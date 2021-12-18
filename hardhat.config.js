require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require('@openzeppelin/hardhat-upgrades');
require('hardhat-deploy')
require("hardhat-deploy-ethers")
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  // solidity: "0.8.4",
  solidity: {
    compilers: [
      {
        version: "0.8.7"
      },
      {
        version: "0.7.5"
      },
      {
        version: "0.7.6"
      }
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.RPC_MAINNET,
        blockNumber: 13815351,
      }
    },
    local: {
      url: process.env.RPC_LOCAL,
      saveDeployments: true
    },
    kovan: {
      url: process.env.RPC_KOVAN,
      accounts: [`0x${process.env.PRIVATE_KEY}`]
    },

    mainnet: {
      url: process.env.RPC_MAINNET,
      // accounts: [`0x${process.env.PRIVATE_KEY}`]      
    }
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },

  mocha: {
    timeout: 700000000
  },

};
