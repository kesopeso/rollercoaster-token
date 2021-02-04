const Presale = artifacts.require('Presale');
const Treasury = artifacts.require('Treasury');
const Buyback = artifacts.require('Buyback');
const { constants } = require('@openzeppelin/test-helpers');

const getWethAddress = (network) => {
    switch (network) {
        case 'mainnet':
            return '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
        case 'rinkeby':
            return '0xc778417E063141139Fce010982780140Aa0cD5Ab';
        default:
            return constants.ZERO_ADDRESS;
    }
};

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
