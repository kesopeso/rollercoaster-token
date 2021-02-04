const Presale = artifacts.require('Presale');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Presale contract migration.');
        return;
    }
    await deployer.deploy(Presale);
};
