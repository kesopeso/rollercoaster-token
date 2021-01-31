const Presale = artifacts.require('Presale');

module.exports = (deployer) => {
    deployer.deploy(Presale);
};
