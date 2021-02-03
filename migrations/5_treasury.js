const Treasury = artifacts.require('Treasury');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async (deployer) => {
    await deployProxy(Treasury, { deployer, initializer: false });
};
