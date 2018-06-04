const utils = require('./utils');
module.exports = {
    'main': {
        isDebug: false,
        cashMinting: 1000 * 10 ** 18
    },
    'Association': {
        minimumSharesToPassAVote: 10000 * 10 ** 18,
        minSecondsForDebate: 6 * 60 * 60,
    },
    'Deposit': {
        mintAmount: 10000 * 10 ** 18,
        approveAmount: 10000 * 10 ** 18,
    },
    'Faucet': {
        libretyAmount: 1000000 * 10 ** 18,
    },
    'Exchanger': {
        mintAmount: 100 * 10 ** 18,
        buyFee: 250,
        sellFee: 250,
        deadline: utils.getTimestamp(+5),
    },
};
