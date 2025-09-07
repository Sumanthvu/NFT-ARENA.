// // filepath: c:\Users\vedan\OneDrive\Desktop\hardhat starter\hardhat.config.js
// require("dotenv").config();
// require("@nomicfoundation/hardhat-toolbox");

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: "0.8.28",
//   paths:{
//     sources:"./contracts",
//     tests:"./test",
//     cache:"./cache",
//     artifacts:"./artifacts"
//   },
//   networks:{
//     hardhat:{
//       chainId:1337
//     },
//     sepolia:{
//       url:"https://eth-sepolia.g.alchemy.com/v2/aKaqFFYutBuSau90H43WY",
//       accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
//     }
//   },
// };

// filepath: c:\Users\vedan\OneDrive\Desktop\hardhat starter\hardhat.config.js
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200, // try 200, can reduce to 50 if still too big
      },
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  networks: {
    hardhat: {
      chainId: 1337,
    },
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/aKaqFFYutBuSau90H43WY",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
};
