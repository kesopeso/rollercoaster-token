const Token = artifacts.require('Token');
const Presale = artifacts.require('Presale');
const Treasury = artifacts.require('Treasury');
const Buyback = artifacts.require('Buyback');
const { deployProxy } = require('@openzeppelin/truffle-upgrades');
const { getTokenWethPairAddress } = require('../lib/uniswap');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Token contract migration.');
        return;
    }

    const presale = await Presale.deployed();
    const treasury = await Treasury.deployed();
    const buyback = await Buyback.deployed();
    const rcFarm = { address: '0x' };
    const rcEthFarm = { address: '0x' };
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
    const uniswapPairAddress = getTokenWethPairAddress(token.address, network);
    await token.setUniswapPair(uniswapPairAddress);
};
