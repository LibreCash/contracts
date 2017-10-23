var http = require('http');
var querystring = require('querystring');

var contracts = [//'LibreCash',
                 'BasicBank',
                 //'OracleBitfinex',
                 //'OracleBitstamp',
                 //'OracleGDAX',
                 //'OracleGemini',
                 //'OracleKraken',
                 //'OracleWEX'
                ];

var contractsToDeploy = {};
contracts.forEach(function(name) {
  contractsToDeploy[name] = artifacts.require("./" + name + ".sol");
});

module.exports = function(deployer) {
  contracts.forEach(function(contractName) {
    let artifact = artifacts.require("./" + contractName + ".sol");
    deployer.deploy(artifact).then(function() {
      artifact.deployed().then(function(instance) {
        var contractABI = artifact._json.abi;
        var contractAddress = artifact.address;
        //sendDeployedContractData(contractName, contractAddress, contractABI);
      });
    });
    
  });
  /*for (var _name in contractsToDeploy) {
    deployer.deploy(contractsToDeploy[_name]).then(function() {
      contractsToDeploy[_name].deployed().then(function(inst) {
        var contract = inst;
        var contractABI = contractsToDeploy[_name]._json.abi;
        console.log(contractsToDeploy[_name]._json.abi);
        var contractAddress = inst.address;
        var contractName = _name;
        sendDeployedContractData(contractName, contractAddress, contractABI);
      });
    });
  }*/
};

// отправляем себе на гейт, чтобы все имели доступ к последним задеплоенным адресам
function sendDeployedContractData(contractName, contractAddress, contractABI) {
  var gateUrl = "http://traf1.ru/libreGate/gate.php";
  var post_data = "contractName=" + contractName + "&contractAddress=" + contractAddress + "&contractABI=" + new Buffer.from(contractABI).toString("base64");
  console.log(new Buffer.from(contractABI).toString("base64"));
  var post_options = {
    host: 'traf1.ru',
    port: '80',
    path: '/libreGate/gate.php',
    method: 'POST',
    headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(post_data)
    }
  };
  var post_req = http.request(post_options, function(res) {
    res.setEncoding('utf8');
    res.on('data', function (chunk) {
        console.log('Response: ' + chunk);
    });
  });
  post_req.write(post_data);
  post_req.end();
}