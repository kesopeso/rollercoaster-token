const Presale = artifacts.require('Presale');

module.exports = async (deployer) => {
    await deployer.deploy(Presale);
};
