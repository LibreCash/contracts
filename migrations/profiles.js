const network_default = {
        host: "localhost",
        port: 8545,
        network_id: "dev",
        gas: 6000000
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
        'OracleMockTest'
    ],
    bounty = [
        'BountyOracle1',
        'BountyOracle2',
        'BountyOracle3'
    ];

module.exports = {
    development: {
        network: network_default,
        contracts: []
    },
    mainnet: {
        network: {
            network_id: "mainnet", // rinkeby, ropsten, main network, etc.
            host: "localhost",
            port: 8545,
            gas: 6000000
        },
        contracts: [...mainnet]
    },
    exchanger: {
        network: network_default,
        contracts: ['LibreCash','ComplexExchanger',...mainnet]
    },
    exchangerLocal: {
        network: network_default,
        contracts: ['LibreCash','ComplexExchanger',...local]
    },
    bank: {
        network: network_default,
        contracts: ['LibreCash','ComplexBank',...mainnet]
    },
    bankLocal: {
        network: network_default,
        contracts: ['LibreCash','ComplexBank',...local]
    },
    dao: {
        network: network_default,
        contracts: ['LibreCash','ComplexBank','Association',...mainnet]
    },
    daoLocal: {
        network: network_default,
        contracts: ['LibreCash','ComplexBank','Association',...local]
    },
    deposit: {
        network: network_default,
        contracts: ['LibreCash','ComplexExchanger','Deposit', ...mainnet]
    },
    depositLocal: {
        network: network_default,
        contracts: ['LibreCash','ComplexExchanger','Deposit', ...local]
    }
}