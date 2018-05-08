module.exports = async function(deployer, contracts, config) {
    let [report] = contracts;
    await deployer.deploy(report);
    await report.deployed();
}