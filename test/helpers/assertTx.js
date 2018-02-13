function AssertTx() {

    this.run = async (_func, _args) => {
        var funcRes;
        try {
            funcRes = await _func(..._args);
        } catch(e) {
            if (~e.toString().indexOf("VM Exception while processing transaction: revert")) {
                funcRes = { receipt: {status: 0 }};
            } else {
                throw new Error(e.toString());
            }
        }
        return funcRes;
    };
  
    this.success = (tx, msg) => {
        return assert.equal(tx.receipt.status, 1, msg);
    };

    this.fail = (tx, msg) => {
        return assert.equal(tx.receipt.status, 0, msg);
    };
  }
  
  module.exports = AssertTx;