const Token = artifacts.require('Token');
const Presale = artifacts.require('Presale');
const Treasury = artifacts.require('Treasury');
const Buyback = artifacts.require('Buyback');
const RcFarm = artifacts.require('RcFarm');
const RcEthFarm = artifacts.require('RcEthFarm');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const { getTokenWethPairAddress } = require('../lib/pancakeswap');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Token contract migration.');
        return;
    }

    const presale = await Presale.deployed();
    const treasury = await Treasury.deployed();
    const buyback = await Buyback.deployed();
    const rcFarm = await RcFarm.deployed();
    const rcEthFarm = await RcEthFarm.deployed();

    await deployProxy(
        Token,
        [
            'RollerCoaster',
            'ROLL',
            presale.address,
            treasury.address,
            buyback.address,
            rcFarm.address,
            rcEthFarm.address,
        ],
        {
            deployer,
        }
    );

    const token = await Token.deployed();
    const pancakeswapPairAddress = getTokenWethPairAddress(token.address, network);
    await token.setpancakeswapPair(pancakeswapPairAddress);
};
