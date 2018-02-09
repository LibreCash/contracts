function Reverter(web3) {

    this.runTx = (_func, _args) => {
        var funcRes;
        try {
            funcRes = await _func(..._args);
        } catch(e) {
            if (e.toString().indexOf("VM Exception while processing transaction: revert") != -1) {
                funcRes = { receipt: {status: 0 }};
            } else {
                throw new Error(e.toString());
            }
        }
        return funcRes;
    };
  
    this.success = (txReceipt, msg) => {
        return assert.equal(tx.receipt.status, 1, msg);
    };

    this.fail = (txReceipt, msg) => {
        return assert.equal(tx.receipt.status, 0, msg);
    };
  }
  
  module.exports = Reverter;