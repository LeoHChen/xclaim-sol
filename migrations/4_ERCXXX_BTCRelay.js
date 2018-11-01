var BTCRelay = artifacts.require("./BTCRelay/BTCRelay.sol");
var ERCXXX_BTCRelay = artifacts.require("./impl/ERCXXX_BTCRelay.sol");

module.exports = function (deployer, network) {
    if (network == "development") {
        deployer.deploy(BTCRelay).then(function () {
            return deployer.deploy(ERCXXX_BTCRelay, BTCRelay.address);
        })
    } else if (network == "ropsten") {
        // Use existing deployed contracts
    }
};
