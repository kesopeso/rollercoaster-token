const Token = artifacts.require('Token');
const Presale = artifacts.require('Presale');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Token contract migration.');
        return;
    }
    const presale = await Presale.deployed();
    await deployProxy(Token, ['RollerCoaster', 'ROLL', presale.address], { deployer });
};
