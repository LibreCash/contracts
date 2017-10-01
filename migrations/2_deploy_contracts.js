var libreToken = artifacts.require("./libreToken.sol");

module.exports = function(deployer) {
  deployer.deploy(libreToken);
};
