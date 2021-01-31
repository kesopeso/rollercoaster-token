require('dotenv').config();
const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
const HDWalletProvider = require('@truffle/hdwallet-provider');
const getNetworkDeploymentConfig = (network, networkId) => {
    const ownerPrivateKey = process.env[`${network.toUpperCase()}_OWNER_PRIVATE_KEY`];
    const providerUrl = `https://${network}.infura.io/v3/${process.env.INFURA_KEY}`;
    const provider = null; //new HDWalletProvider(ownerPrivateKey, providerUrl);
    const network_id = networkId;
    const gas = Number(process.env.DEPLOY_GAS);
    const gasPrice = Number(`${process.env[`${network.toUpperCase()}_DEPLOY_GAS_PRICE_IN_GWEI`]}000000000`);
    const skipDryRun = true;
    return {
        provider,
        network_id,
        gas,
        gasPrice,
        skipDryRun,
    };
};

module.exports = {
    networks: {
        development: {
            host: '127.0.0.1', // Localhost (default: none)
            port: 8545, // Standard Ethereum port (default: none)
            network_id: '*', // Any network (default: none)
        },
        rinkeby: getNetworkDeploymentConfig('rinkeby', 4),
        kovan: getNetworkDeploymentConfig('kovan', 42),
        mainnet: getNetworkDeploymentConfig('mainnet', 1),
    },

    // Set default mocha options here, use special reporters etc.
    mocha: {
        // timeout: 100000
    },

    // Configure your compilers
    compilers: {
        solc: {
            version: '0.6.12', // Fetch exact version from solc-bin (default: truffle's version)
            // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            // settings: {          // See the solidity docs for advice about optimization and evmVersion
            //  optimizer: {
            //    enabled: false,
            //    runs: 200
            //  },
            //  evmVersion: "byzantium"
            // }
        },
    },
    plugins: ['truffle-plugin-verify'],
    api_keys: {
        etherscan: etherscanApiKey,
    },
};
