require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require('hardhat-contract-sizer');
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  settings: {
    optimizer: {
      enabled: true,
      runs: 500
    }
  },
  networks: {
    testnet: {
      url: 'https://erpc.apothem.network',
      accounts: [process.env.MNENOMIC],
    },
    xdc:{
      url: 'https://erpc.xinfin.network',
      accounts: [process.env.MNENOMIC],
    }
  },

  abiExporter: [
    {
      path: './abi/pretty',
      pretty: true,
    },
    {
      path: './abi/ugly',
      pretty: false,
    },
    {
      path: './abi/minimal',
      format: "minimal",
    
    }
  ],

  // contractSizer: {
  //   alphaSort: true,
  //   disambiguatePaths: false,
  //   runOnCompile: true,
  //   strict: true,
  // }

};
