const ERCXXX_SGX = artifacts.require("./impl/ERCXXX_SGX.sol");

// Writing experiments data to CSV
var fs = require("fs");
var csvWriter = require('csv-write-stream');
var writer = csvWriter();

// Integrate with bitcoin
const Client = require('bitcoin-core');


contract('ERCXXX_SGX', async (accounts) => {
    /* For testing and experiments the following roles apply: */
    const issuer = accounts[0];
    const collateral = 0;
    const alice = accounts[1];
    const bob = accounts[2];
    const btc_tx = "3a7bdf6d01f068841a99cce22852698df8428d07c68a32d867b112a4b24c8fe0";


    // experiment related vars
    var authorize_gas;
    var issue_gas;
    var trade_offer_gas;
    var trade_accept_gas;
    var transfer_gas;
    var redeem_gas;

    before('Create writer for experiments', async () => {
        writer.pipe(fs.createWriteStream(('./experiments/Gas_ERCXXX_SGX.csv')));
    })

    after('Write experiment data to file', async () => {
        writer.write(
            {
                Authorize: authorize_gas,
                TradeOffer: trade_offer_gas,
                TradeAccept: trade_accept_gas,
                Issue: issue_gas,
                Transfer: transfer_gas,
                Redeem: redeem_gas
            });
        writer.end();
    })

    beforeEach('setup contract', async function () {
        btc_erc = await ERCXXX_SGX.new("BTC-ERC", "BTH", 1);
    });

    it("Authorize issuer", async () => {
        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");
        authorize_gas = authorize_tx.receipt.gasUsed;

        // check if issuer list is updated
        let updatedIssuer = await btc_erc.issuer.call();

        assert.isTrue(web3.isAddress(updatedIssuer));
        assert.equal(updatedIssuer, issuer);
    });

    it("Authorize and revoke issuer", async () => {
        // TODO: Implement test to revoke issuer
        let initialIssuer = await btc_erc.issuer.call();

        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");
        // console.log(authorize_tx.receipt.gasUsed);

        // let revoke_tx = await btc_erc.revokeIssuer(issuer, { from: issuer});
        // eventFired(revoke_tx, "RevokedIssuer");

        // check if issuer list is updated
        // let updatedIssuerList = await btc_erc.issuerList.call();

        // assert.equal(initialIssuerList, updatedIssuerList);
        assert.isTrue(true);
    });

    it("Issue tokens", async () => {
        let balance_alice;
        let amount = 1;

        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");

        balance_alice = await btc_erc.balanceOf.call(alice);
        let init_balance_alice = balance_alice.toNumber();

        // check if issue event is fired
        let issue_tx = await btc_erc.issue(alice, amount, btc_tx);
        eventFired(issue_tx, "Issue");
        issue_gas = issue_tx.receipt.gasUsed;

        balance_alice = await btc_erc.balanceOf.call(alice);
        let updated_balance_alice = balance_alice.toNumber();
        
        // check if Alice's balance is updated
        assert.isAbove(updated_balance_alice, init_balance_alice)
        assert.equal(updated_balance_alice, 1)        
    });


    it("Abort token creation", async () => {
        // Not sure if we can test this in Ethereum?

        let btc_erc = await ERCXXX_SGX.deployed();

        assert.isTrue(true);
    });

    it("Trade tokens", async () => {
        let balance_alice, balance_bob;
        let amount = 1;

        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");

        // check if issue event is fired
        let issue_tx = await btc_erc.issue(alice, amount, btc_tx);
        eventFired(issue_tx, "Issue");

        // check if Alice's balance is updated
        balance_alice = await btc_erc.balanceOf.call(alice);
        balance_alice = balance_alice.toNumber();
        assert.equal(balance_alice, amount, "Alice balance should be 1");

        // Offer exchange of 1 token for 100 wei
        let offer_tx = await btc_erc.offerTrade(1, 100, bob, {from: alice});
        // Check event is fired
        eventFired(offer_tx, "NewTradeOffer");
        trade_offer_gas = offer_tx.receipt.gasUsed;
        /* Get offer id*/
        var offerId = 0;
        for (var i = 0; i < offer_tx.logs.length; i++) {
            var log = offer_tx.logs[i];
            if (log.event == "NewTradeOffer") {
                // We found the event!
                offerId = log.args.id.toString();
            }
        }
        // Complete the transfer
        let trade_tx = await btc_erc.acceptTrade(offerId, {from: bob, value: 100});
        // Check event is fired
        eventFired(trade_tx, "Trade");
        trade_accept_gas = trade_tx.receipt.gasUsed;

        // check if balances are updated
        balance_alice = await btc_erc.balanceOf.call(alice);
        balance_alice = balance_alice.toNumber();
        balance_bob = await btc_erc.balanceOf.call(bob);
        balance_bob = balance_bob.toNumber();

        assert.equal(balance_alice, 0, "Alice balance should be 0");
        assert.equal(balance_bob, amount, "Bob balance should be 1");
    });

    it("Transfer tokens", async () => {
        let balance_alice, balance_bob;
        let amount = 1;

        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");

        // check if issue event is fired
        let issue_tx = await btc_erc.issue(alice, amount, btc_tx);
        eventFired(issue_tx, "Issue");

        // check if Alice's balance is updated
        balance_alice = await btc_erc.balanceOf.call(alice);
        balance_alice = balance_alice.toNumber();
        assert.equal(balance_alice, amount, "Alice balance should be 1");

        // check if transfer event fired
        let transfer_tx = await btc_erc.transfer(alice, bob, 1, {from: alice});
        eventFired(transfer_tx, "Transfer");
        transfer_gas = transfer_tx.receipt.gasUsed;

        // check if balances are updated
        balance_alice = await btc_erc.balanceOf.call(alice);
        balance_alice = balance_alice.toNumber();
        balance_bob = await btc_erc.balanceOf.call(bob);
        balance_bob = balance_bob.toNumber();

        assert.equal(balance_alice, 0, "Alice balance should be 0");
        assert.equal(balance_bob, amount, "Bob balance should be 1");
    });

    it("Redeem tokens", async () => {
        let balance_alice;
        let amount = 1;

        // check if authorize event fired
        let authorize_tx = await btc_erc.authorizeIssuer(issuer, { from: issuer, value: web3.toWei(collateral, "ether") });
        eventFired(authorize_tx, "AuthorizedIssuer");

        // check if issue event is fired
        let issue_tx = await btc_erc.issue(alice, amount, btc_tx);
        eventFired(issue_tx, "Issue");

        // check if Alice's balance is updated
        balance_alice = await btc_erc.balanceOf.call(alice);
        balance_alice = balance_alice.toNumber();
        assert.equal(balance_alice, 1, "Alice balance should be 1");

        // check if redeem event fired
        let redeem_tx = await btc_erc.redeem(alice, amount, btc_tx, { from: issuer });
        eventFired(redeem_tx, "Redeem");
        redeem_gas = redeem_tx.receipt.gasUsed;
    });

    function eventFired(transaction, eventName) {
        for (var i = 0; i < transaction.logs.length; i++) {
            var log = transaction.logs[i];
            if (log.event == eventName) {
                // We found the event!
                assert.isTrue(true);
            }
            else {
                assert.isTrue(false);
            }
        }
    };

})
