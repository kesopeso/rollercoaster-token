const Migrations = artifacts.require('Migrations');

module.exports = async (deployer, network) => {
    if (network === 'test') {
        console.log('Testing... Skipping Migration contract migration.');
        return;
    }
    await deployer.deploy(Migrations);
};
