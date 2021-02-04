const Token = artifacts.require('TokenMock');
const Presale = artifacts.require('Presale');
const { ether } = require('@openzeppelin/test-helpers');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Token contract migration.');
        return;
    }
    const presale = await Presale.deployed();
    const mintAmount = ether('3227');
    await deployer.deploy(Token, presale.address, mintAmount);
};
