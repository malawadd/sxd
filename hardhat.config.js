require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
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
  ]

};
