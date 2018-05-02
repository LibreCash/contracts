module.exports = async function(deployer, contracts, config) {
    await Promise.all(contracts.map((oracle) => deployer.deploy(oracle, 0)))
}