const Presale = artifacts.require('Presale');
const Treasury = artifacts.require('Treasury');
const Buyback = artifacts.require('Buyback');
const { getWethAddress } = require('../lib/pancakeswap');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Buyback contract migration.');
        return;
    }
    const presale = await Presale.deployed();
    const treasury = await Treasury.deployed();
    const wethAddress = getWethAddress(network);
    await deployer.deploy(Buyback, presale.address, treasury.address, wethAddress);
};
