function Reverter (web3) {
    this.snapshotId = 0;

    this.revert = (done, id) => {
        let toSnapshotId = (id !== undefined) ? id : this.snapshotId;
    
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_revert',
            id: new Date().getTime(),
            params: [toSnapshotId],
        }, (err, result) => {
            if (err) {
                done(err);
            } else {
                this.snapshot(done);
            }
        });
    };

    this.snapshot = (done) => {
        web3.currentProvider.sendAsync({
            jsonrpc: '2.0',
            method: 'evm_snapshot',
            id: new Date().getTime(),
        }, (err, result) => {
            if (err) {
                done(err);
            } else {
                this.snapshotId = web3.toDecimal(result.result);
                done();
            }
        });
    };
}

module.exports = Reverter;
