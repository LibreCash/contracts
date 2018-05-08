const
    expectThrow = require('../helpers/expectThrow'),
    BurnableToken = artifacts.require('LibreCash'),
    BigNumber = web3.BigNumber;

contract('BurnableToken', function (accounts) {
    let token;
    let expectedTokenSupply = new BigNumber(999);

    beforeEach(async function () {
        token = await BurnableToken.new();
        await token.mint(accounts[0], 1000);
    });

    it('owner should be able to burn tokens', async function () {
        await token.burn(1, { from: accounts[0] });

        const balance = +await token.balanceOf(accounts[0]);
        assert.equal(balance, expectedTokenSupply, 'balance and tokenSupply don\'t equal!');

        const totalSupply = +await token.totalSupply();
        assert.equal(totalSupply, expectedTokenSupply, 'totalSupply not right!');
    });

    it('cannot burn more tokens than your balance', async function () {
        await expectThrow(token.burn(2000, { from: accounts[0] }));
    });
});
