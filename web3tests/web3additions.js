function logTransactionByReceipt(_txid) {
    function hex2str(hex) {
        if (hex.substr(0, 2) == "0x") {
            hex = hex.substr(2);
        }
        var str = '';
        for (var i = 0; i < hex.length; i += 2)
            str += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
        return str;
    }
    var _name = arguments.callee.caller.name;
    
    if (_txid) {
        let receipt = web3.eth.getTransactionReceipt(_txid);
        if (receipt.status) {
            if (receipt.status == "0x1") {
                console.log(_name + ': SUCCESS (' + _txid + ')');
            }
            else if (receipt.status == "0x0") {
                console.log(_name + ': FAIL (' + _txid + ')');
            }
            else {
                console.log(_name + ': UNRECOGNIZED STATUS: ' + receipt.status + ' (' + _txid + ')');
            }
        }
        else {
            console.log(_name + ': problem getting tx status');
        }
        if (receipt.logs) {
            receipt.logs.forEach(function(_log) {
                if (_log.topics) {
                    _log.topics.forEach(function(_topic) {
                        // todo: расшифровка topics
                        console.log(hex2str(_topic));
                    });
                }
                else {
                    console.log(_log); // to debug
                    console.log(' ... no log topics');
                }
            });
        }
        else {
            console.log(' ... with no logs');
        }
    }
    else
        console.log(_name + ': txid not provided');
}

web3.eth.getTransactionReceiptMined = function(txnHash) {
    var transactionReceiptAsync;
    interval = 100;
    transactionReceiptAsync = function(txnHash, resolve, reject) {
        try {
            var receipt = web3.eth.getTransactionReceipt(txnHash);
            if (receipt == null) {
                setTimeout(function () {
                    transactionReceiptAsync(txnHash, resolve, reject);
                }, interval);
            } else {
                resolve(receipt);
            }
        } catch(e) {
            reject(e);
        }
    };

    if (Array.isArray(txnHash)) {
        var promises = [];
        txnHash.forEach(function (oneTxHash) {
            promises.push(web3.eth.getTransactionReceiptMined(oneTxHash));
        });
        return Promise.all(promises);
    } else {
        return new Promise(function (resolve, reject) {
                transactionReceiptAsync(txnHash, resolve, reject);
            });
    }
};