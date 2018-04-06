const
    reverter = new (require('./helpers/reverter'))(web3),
    timeMachine = new (require('./helpers/timemachine'))(web3),
    assertTx = new (require('./helpers/assertTx'))(),
    utils = new (require('./helpers/utils'))(),
    tokenMultiplier = Math.pow(10, 18),
    MORE_THAN_COSTS = web3.toWei(5,'ether'),
    ComplexExchanger = artifacts.require("ComplexExchanger"),
    LibreCash = artifacts.require("LibreCash"),
    Loans = artifacts.require("Loans");

function getLoanStruct(contractArray) {
    return {
        holder: contractArray[0],
        recipient: contractArray[1],
        timestamp: +contractArray[2][0],
        period: +contractArray[2][1],
        amount: +contractArray[2][2],
        margin: +contractArray[2][3],
        return: +contractArray[2][4],
        pledge: +contractArray[2][5],
        status: +contractArray[3]
    }
}


contract("Loans",function(accounts) {
    var owner = accounts[0],
        acc1  = accounts[1],
        exchanger,
        token,
        loans;

    before("init var", async function() {
        exchanger = await ComplexExchanger.deployed();
        token = await LibreCash.deployed();
        loans = await Loans.deployed();
    });

    context("loansEth",function() {
        before("init", reverter.snapshot);
        afterEach("revert", reverter.revert);

        it("create loan", async function() {
            let before = web3.eth.getBalance(owner);
            await loans.giveEth(1,web3.toWei(2,'ether'),web3.toWei(3,'ether'),{value: web3.toWei(4,'ether')});
            let after = web3.eth.getBalance(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));
            let takeEth = web3.fromWei(before - after - utils.gasCost());

            assert.isBelow(Math.abs(2 - takeEth),0.00001,"Take Eth not equal!");
            assert.equal(loan.holder, owner, "Holder not right!");
            assert.equal(loan.period, 1,"Period not right!");
            assert.equal(loan.amount, web3.toWei(2,'ether'),"Amount not right!");
            assert.equal(loan.margin, web3.toWei(3,'ether'),"Margin not right!");
            assert.equal(loan.status, 0, "Status not right!");
        });
        
        it("create loan without Eth", async function() {
            await assertTx.fail(loans.giveEth(1,web3.toWei(1,'ether'),web3.toWei(1,'ether')),
              'Not fail tx without send Eth!')
        });

        it("cancel loan", async function() {
            let before = web3.eth.getBalance(owner);
            await loans.giveEth(1,web3.toWei(2,'ether'),web3.toWei(3,'ether'),{value: web3.toWei(4,'ether')});
            let gasCost = utils.gasCost();
            await loans.cancelEth(0);
            gasCost += utils.gasCost();
            let after = web3.eth.getBalance(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));

            assert.equal(loan.status,2,"Don't right status!");
            assert.isBelow(before - after - gasCost, 10000, "Don't right balacne after cancel loan!");
            await assertTx.fail(loans.cancelEth(0),"Tx don't fail if loan have completed status!")
        });

        it("cancel active loan", async function() {
            await loans.giveEth(1,2,3,{value: 4});

            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            await token.mint(owner,10000);
            await token.approve(loans.address,10000);
            await loans.takeLoanEth(0);

            await assertTx.fail(loans.cancelEth(0),"Tx don't fail, if loan have used status!");
        });

        it("take loan",async function() {
            await loans.giveEth(1000,1,0,{value: 1});
            await assertTx.fail(loans.takeLoanEth(0),"Tx don't fail with not actual rate!")

            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            await token.mint(owner,10000);
            let before = await token.balanceOf(owner);

            await token.approve(loans.address,10000);
            await loans.takeLoanEth(0);
            let after = await token.balanceOf(owner);
            let loan = getLoanStruct(await loans.getLoanEth(0));

            assert.equal(+before.minus(after), loan.pledge, "token give and pledge not equal!");
            assert.equal(loan.recipient,owner,"Don't right recipient!");
        });

        it("return amount tokens", async function() {
            let period = 1
            await loans.giveEth(period,1,0,{value: 1});

            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            await token.mint(acc1,10000);
            await token.approve(loans.address,10000,{from: acc1});
            let beforeToken = await token.balanceOf(acc1);
            await loans.takeLoanEth(0,{from: acc1});

            await timeMachine.jump(period + 1);

            await assertTx.fail(loans.returnEth(0,{from: acc1}),"Tx not fail when not send ETH!");

            let loan = getLoanStruct(await loans.getLoanEth(0));
            await loans.returnEth(0,{value: loan.return, from: acc1})
            let afterToken = await token.balanceOf(acc1);

            assert.equal(beforeToken.minus(afterToken),0,"Not return all pledge tokens!")
        });

        it("return amount ether",async function() {
            let period = 1
            await loans.giveEth(period,web3.toWei(1,'ether'),0,{value: web3.toWei(1,'ether')});
            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            let loan = getLoanStruct(await loans.getLoanEth(0));
            await token.mint(acc1,loan.pledge);
            await token.approve(loans.address,loan.pledge,{from: acc1});

            await loans.takeLoanEth(0,{from: acc1});
            await timeMachine.jump(period + 1);

            await assertTx.fail(loans.returnEth(0,{from: acc1}),"Tx not fail when not send ETH!");

            let before = web3.eth.getBalance(acc1);
            await loans.returnEth(0,{value: +web3.toWei(1,'ether') + loan.return, from: acc1})
            let after = web3.eth.getBalance(acc1);
            let sendEth = before.minus(after).minus(utils.gasCost());

            assert.equal(+sendEth,loan.return,"Not equal get Ether and need to return!")
        });

        it("claim",async function() {
            let period = 1,
                give = +web3.toWei(1,'ether'),
                margin = +web3.toWei(0.2,'ether');
            await loans.giveEth(period,give,margin,{value: web3.toWei(3,'ether')})

            await assertTx.fail(loans.claimEth(0),"Claim loan in active status!")

            await exchanger.requestRates({value: MORE_THAN_COSTS});
            await exchanger.calcRates();

            let loan = getLoanStruct(await loans.getLoanEth(0));
            await token.mint(acc1,loan.pledge);
            await token.approve(loans.address,loan.pledge,{from: acc1});
            await loans.takeLoanEth(0,{from: acc1});

            await assertTx.fail(loans.claimEth(0),"Claim loan if not timeout!")

            await timeMachine.jump(period + 1);
            await exchanger.refillBalance({value: loan.return * 2});

            let before = web3.eth.getBalance(owner);
            await loans.claimEth(0);
            let after = web3.eth.getBalance(owner);
            let giveEth = after.minus(before);

            assert.equal(+giveEth.minus(give + margin).plus(utils.gasCost()), 0,
              "Don't return need value!")
        });
    });

    context("loanLibre",function() {
        it("create");
        it("cancel");
        it("take");
        it("return");
        it("claim");
    });
});