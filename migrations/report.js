module.exports = async function(deployer, report, config) {
    await deployer.deploy(report);
    await report.deployed();
}