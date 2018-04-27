module.exports = async function(deployer, contracts, config) {
    let [bountyBank, bountyExchanger, ...oracles] = contracts;

    await Promise.all(oracles.map((oracle) => deployer.deploy(oracle)))
    let oraclesAddress = oracles.map((oracle) => oracle.address);

    await deployer.deploy(bountyBank, config.deadline, oraclesAddress);
    await deployer.deploy(bountyExchanger, config.deadline, oraclesAddress);
}