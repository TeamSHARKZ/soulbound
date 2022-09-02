require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('dotenv').config();
require('hardhat-gas-reporter');
require('@openzeppelin/hardhat-upgrades');
require('hardhat-contract-sizer');

if (process.env.REPORT_COVERAGE == 1) {
  require('solidity-coverage');
}

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
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
  solidity: {
    version: '0.8.15',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  defaultNetwork: 'hardhat',
  networks: {
    rinkeby: {
      url: process.env.RINKEBY_URL,
      accounts: [process.env.RINKEBY_WALLET_KEY],
    },
    goerli: {
      url: process.env.GOERLI_URL,
      accounts: [process.env.GOERLI_WALLET_KEY],
    },
    mainnet: {
      url: process.env.MAINNET_URL,
      accounts: [process.env.HOMESTEAD_WALLET_KEY],
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS == 1,
    currency: 'USD',
    gasPrice: 30,
    showTimeSpent: true,
  },
  plugins: ['solidity-coverage'],
  contractSizer: {
    alphaSort: false,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
    only: ['Soul', 'Upgradeable'],
  },
};
