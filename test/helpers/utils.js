function Utils() {
    this.now = () => {
        return web3.eth.getBlock(web3.eth.blockNumber).timestamp;
    }

    this.gasCost = () => {
        let
            lastBlock = web3.eth.getBlock("latest"),
            gasUsed = lastBlock.gasUsed,
            gasPrice = + web3.eth.getTransaction(lastBlock.transactions[0]).gasPrice;

        return gasUsed * gasPrice;
    }
}

module.exports = Utils;