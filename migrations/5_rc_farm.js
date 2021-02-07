const RcFarm = artifacts.require('RcFarm');
const Presale = artifacts.require('Presale');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping RcFarm contract migration.');
        return;
    }
    const presale = await Presale.deployed();
    await deployProxy(RcFarm, [presale.address], { deployer });
};
