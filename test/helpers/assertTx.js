function AssertTx() {

    this.run = async promise => {
        var funcRes;
        try {
            funcRes = await promise;
        } catch(e) {
            if (e.toString().search("revert") >= 0 || e.message.search("invalid opcode") >= 0) {
                funcRes = { receipt: {status: 0 }};
            } else {
                throw new Error(e.toString());
            }
        }
        return funcRes;
    };
  
    this.success = async (promise, msg) => {
        return assert.equal((await this.run(promise)).receipt.status, 1, msg);
    };

    this.fail = async (promise, msg) => {
        return assert.equal((await this.run(promise)).receipt.status, 0, msg);
    };
  }
  
  module.exports = AssertTx;