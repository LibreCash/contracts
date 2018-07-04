const network_default = {
    host: 'localhost',
    port: 8545,
    network_id: '*',
    gas: 6000000,
    gasPrice: 5000000000,
},
mainnet = [
    'OracleBitfinex',
    'OracleBitstamp',
    'OracleWEX',
    'OracleGDAX',
    'OracleGemini',
    'OracleKraken',
],
local = [
    'OracleMockLiza',
    'OracleMockSasha',
    'OracleMockKlara',
    'OracleMockTest',
],
bounty = [
    'BountyOracle1',
    'BountyOracle2',
    'BountyOracle3',
];

module.exports = {
development: {
    network: network_default,
    contracts: [],
},
mainnet: {
    network: {
        network_id: 'mainnet', // rinkeby, ropsten, main network, etc.
        host: 'localhost',
        port: 8545,
        gas: 6000000,
        gasPrice: 3000000000,
    },
    contracts: [...mainnet],
},
exchanger: {
    network: network_default,
    contracts: ['OracleStore', 'OracleFeed', 'LibreCash', 'ComplexExchanger', ...mainnet],
},
exchangerLocal: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', ...local],
},
testExchanger: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', 'Loans', 'Deposit', ...local],
},
bank: {
    network: network_default,
    contracts: ['OracleStore', 'OracleFeed', 'LibreCash', 'ComplexBank', ...mainnet],
},
bankLocal: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', ...local],
},
common: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', 'Association',
        'LibertyToken', 'Loans', 'Deposit', 'LBRSFaucet', ...mainnet],
},
testBank: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', ...local],
},
dao: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', 'Association', 'LibertyToken', ...mainnet],
},
daoLocal: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', 'Association', 'LibertyToken', ...local],
},
testDAO: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', 'Association', 'LibertyToken', ...local],
},
deposit: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', 'Deposit', ...mainnet],
},
depositLocal: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', 'Deposit', ...local],
},
loans: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', 'Loans', ...mainnet],
},
loansLocal: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexExchanger', 'Loans', ...local],
},
faucet: {
    network: network_default,
    contracts: ['LibreCash', 'ComplexBank', 'Association', 'LibertyToken', 'LBRSFaucet', ...mainnet],
},
bounty: {
    network: network_default,
    contracts: ['ComplexBankBounty', 'ComplexExchangerBounty', ...bounty],
},
report: {
    network: network_default,
    contracts: 'ReportStorage',
},

};
