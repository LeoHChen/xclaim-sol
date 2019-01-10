const truffleAssert = require('truffle-assertions');
var helpers = require('../helpers');
var eventFired = helpers.eventFired;

const XCLAIM = artifacts.require("./XCLAIM.sol");


contract('SUCCESS: XCLAIM', async (accounts) => {
    /* For testing and experiments the following roles apply: */
    const issuer = accounts[0];
    const relayer = accounts[1];
    const alice = accounts[2];
    const bob = accounts[3];
    const oracle = accounts[10];

    const amount = 1;
    const collateral = "0.01";
    const collateral_user = "0.00000001";

    let user_collateral = web3.utils.toWei(collateral_user, "ether");

    const btc_tx = web3.utils.hexToBytes("0x3a7bdf6d01f068841a99cce22852698df8428d07c68a32d867b112a4b24c8fe0");

    beforeEach('setup contract', async function () {
        btc_erc = await XCLAIM.deployed();
    });

    it("Adjust BTC/ETH conversion rate", async function () {
        const new_conversion_rate = "3";

        let conversion_rate = await btc_erc.getEthtoBtcConversion.call({from: oracle});
        await btc_erc.setEthtoBtcConversion(new_conversion_rate);
        assert.notEqual(conversion_rate,new_conversion_rate, "Did not update the conversion rate");
        
        let updated_conversion_rate = await btc_erc.getEthtoBtcConversion.call({from: oracle});
        assert.equal(updated_conversion_rate,new_conversion_rate, "Updated the conversion rate to wrong value");
    })

    it("Set conversion rate to 0 not possible", async function () {
        const new_conversion_rate = "0";

        await truffleAssert.reverts(
            btc_erc.setEthtoBtcConversion(new_conversion_rate),
            "Set rate greater than 0"
        );
    })
})