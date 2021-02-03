const Treasury = artifacts.require('Treasury');

module.exports = async (deployer) => {
    await deployer.deploy(Treasury);
};
