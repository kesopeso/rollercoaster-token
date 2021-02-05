const Treasury = artifacts.require('Treasury');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Treasury contract migration.');
        return;
    }
    await deployProxy(Treasury, { deployer, initializer: false });
};
