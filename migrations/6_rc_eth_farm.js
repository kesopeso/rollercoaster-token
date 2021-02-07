const RcEthFarm = artifacts.require('RcEthFarm');
const Presale = artifacts.require('Presale');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping RcEthFarm contract migration.');
        return;
    }
    const presale = await Presale.deployed();
    await deployProxy(RcEthFarm, [presale.address], { deployer });
};
