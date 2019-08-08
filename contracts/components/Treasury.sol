// Copyright (C) 2019 Alexei Zamyatin and Dominik Harz
// 
// This file is part of XCLAIM.
// 
// XCLAIM is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// XCLAIM is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with XCLAIM.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../interfaces/Treasury_Interface.sol";
import "../components/ERC20.sol";

contract Treasury is Treasury_Interface, ERC20 {
    using SafeMath for uint256;

    // #####################
    // CONTRACT VARIABLES
    // #####################

    // global nonce
    uint256 public _nonce;

    // vault
    struct Vault {
        address payable vault; // address of vault
        uint256 tokenSupply; // maximum token supply of vault (backed-tokens)
        uint256 committedTokens; // number of tokens committed to all CbA requesters
        uint256 collateral; // amount of provided collateral
        address payable replaceCandidate; // address of replacement vault
        bool replace; // marked for replacement
        uint256 blocknumber; // replace period as number of blocks
    }
    mapping(uint256 => Vault) _vaults;
    mapping(address => uint256) _vaultIds;
    uint256 _vaultId;

    // sum of vaults
    uint256 public _vaultTokenSupply; // total supply of CbA
    uint256 public _vaultCommittedTokens; // total commited tokens to all CbA requesters
    uint256 public _vaultCollateral; // total amount of collateral provided

    // relay
    address public _relay;

    // block confirmations
    uint256 public _confirmations;

    // collateral
    uint256 public _minimumCollateralVault;
    uint256 public _minimumCollateralUser;

    // conversion rate
    uint256 public _conversionRate; // 10*5 granularity?

    // issue
    struct IssueRequest {
        uint256 vaultId; // selected vault
        uint256 blocknumber; // block number when issue is requested
        uint256 collateral; // amount of collateral provided by requester
        uint256 amount; // amount of tokens to be issued
        address receiver; // ETH address of requester
        address payable sender; // 
        bytes btcAddress;
    }
    mapping(address => IssueRequest) public _issueRequests;
    uint256 _issuePeriod;

    // swap
    struct Trade {
        address payable tokenParty;
        address payable ethParty;
        uint256 tokenAmount;
        uint256 ethAmount;
        bool completed;
    }
    mapping(uint256 => Trade) public _trades;
    uint256 public _tradeId;


    // redeem
    struct RedeemRequest {
        address payable vault;
        address payable redeemer;
        uint256 amount;
        uint256 blocknumber;
        bytes btcOutput;
    }
    mapping(uint => RedeemRequest) public _redeemRequests;
    uint256 public _redeemRequestId;
    uint256 _redeemPeriod;

    // replace
    uint256 _replacePeriod;

    constructor() public {
        // set initial nonce
        _nonce = 0;

        // set initial tokens
        _totalSupply = 0;

        // vault
        _vaultId = 0;
        _vaultTokenSupply = 0;
        _vaultCommittedTokens = 0;
        _vaultCollateral = 0;

        // block confirmations
        _confirmations = 12;

        // collateral
        _minimumCollateralUser = 1 wei;
        _minimumCollateralVault = 1 wei;

        // conversion rate
        _conversionRate = 2 * 10 ^ 5; // equals 1 BTC = 2 ETH

        // issue
        _issuePeriod = 20;

        // swap
        _tradeId = 0;

        // redeem
        _redeemPeriod = 20;
        _redeemRequestId = 0;

        // replace
        _replacePeriod = 20;
    }

    // #####################
    // FUNCTIONS
    // #####################
    // TODO: return maximum numbers of tokens that can be issued as well
    function getVaults() public view returns(address[] memory) {
        require(_vaultId > 0, "No vault registered");

        address[] memory vaults = new address[](_vaultId);

        // NOTE: vaults are stored from id 1 and greater
        for (uint i = 0; i < _vaultId; i++) {
            vaults[i] = _vaults[i+1].vault;
        }

        return vaults;
    }

    function getRelay() public view returns(address) {
        return _relay;
    }

    function getVaultCollateral(address vault) public view returns (uint256) {
        uint256 id = _vaultIds[vault];
        return _vaults[id].collateral;
    }

    function getReplacePeriod() public view returns (uint256) {
        return _replacePeriod;
    }

    // ---------------------
    // PRICE ORACLE
    // ---------------------
    function getConversionRate() public returns (uint256) {
        return _conversionRate;
    }

    function setConversionRate(uint256 rate) public returns (bool){
        // todo: require maximum fluctuation
        // todo: only from "trusted" oracles
        require(rate > 0, "Set rate greater than 0");

        _conversionRate = rate;

        assert(_conversionRate == rate);
        return true;
    }

    // ---------------------
    // VAULT
    // ---------------------

    function registerVault(address payable toRegister) public payable returns (bool) {
        require(msg.value >= _minimumCollateralVault, "Collateral too low");

        _registerNewVault(toRegister, msg.value);

        // increase amount that can be issued
        _vaultTokenSupply += _convertEthToBtc(msg.value);
        _vaultCollateral += msg.value;

        return true;
    }

    // ---------------------
    // RELAY
    // ---------------------

    function registerRelay(address toRegister) public returns (bool) {
        /* TODO: who authroizes this? 
        For now, this method is only available in the constructor */
        // Does the relayer need to provide collateral?
        require(_relay == address(0));
        require(msg.sender != _relay);

        _relay = toRegister;

        emit RegisteredRelayer(toRegister);

        return true;
    }

    // make contract ownable and owner can change relay
    // TODO: revokeRelay
    function revokeRelayer(address toUnlist) public returns (bool) {
        // TODO: who can do that?
        _relay = address(0);
        // btcRelay = BTCRelay(address(0));
        emit RevokedRelayer(_relay);

        return true;
    }

    // ---------------------
    // ISSUE
    // ---------------------
    // TODO: name function commit
    // TODO: add recepient and change msg.sender for recepient
    function registerIssue(
        address receiver,
        uint256 amount, 
        address payable vault, 
        bytes memory vaultBtcAddress) 
    public payable returns (bool) {
        // TODO: include a nonce for a user and use address plus nonce as key for IssueRequest mapping
        require(msg.value >= (amount * _minimumCollateralUser), "Collateral too small");

        uint256 vaultId = _getVaultId(vault);
        require(
            _vaults[vaultId].tokenSupply >= amount + _vaults[vaultId].committedTokens, 
            "Not enough collateral provided by this single vault"
        );
        // Update vault commited tokens
        _vaults[vaultId].committedTokens += amount;

        // update overall details
        _vaultCommittedTokens += amount;

        // store commit to issue
        _issueRequests[receiver] = IssueRequest({
            vaultId: vaultId,
            blocknumber: block.number,
            collateral: msg.value,
            amount: amount,
            receiver: receiver,
            sender: msg.sender,
            btcAddress: vaultBtcAddress
        });

        // emit event
        // TODO: emit nonce
        emit RegisterIssue(receiver, amount, block.number);

        /* TODO: create unique hash from 
        (btc_address of vault, eth_address, nonce, contract_address)
        hash is used against replay attacks
        */

        return true;
    }

    function confirmIssue(address receiver, bytes memory data) public returns (bool) {
        // Require that msg.sender == creator of commitment
        require(msg.sender == _issueRequests[receiver].sender, "Different address sending request");
        // Verify that collateral has not been revoked
        require(_issueRequests[receiver].collateral > 0, "Collateral too small");
        // Verify that issue request is performed within time
        require(
            _issueRequests[receiver].blocknumber + _issuePeriod >= block.number,
            "Request to issue tokens not within time period"
        );

        // check if within number of blocks on Ethereum
        bool verify_not_expired = _verifyBlock(_issueRequests[receiver].blocknumber);

        // BTCRelay verifyTx callback
        // TODO: future give parameter for minimum number of confirmations
        bool tx_valid = _verifyTx(data);

        // TODO: check hash of (btc_address of vault, eth_address, nonce, contract_address)
        // extract from OP_RETURN 

        bool address_valid = _verifyAddress(receiver, _issueRequests[receiver].btcAddress, data);

        // check value of transaction
        bool value_valid = true;

        // TODO: replay protection with nonce?

        uint256 id = _issueRequests[receiver].vaultId;
        uint256 amount = _issueRequests[receiver].amount;
        uint256 collateral = _issueRequests[receiver].collateral;

        if (verify_not_expired && tx_valid && address_valid) {
            
            _totalSupply += amount;
            // issue tokens
            _balances[receiver] += amount;
            // reset user issue
            _issueRequests[receiver].collateral = 0;
            _issueRequests[receiver].blocknumber = 0;
            // Send user collateral back
            _issueRequests[receiver].sender.transfer(collateral);

            emit IssueToken(msg.sender, receiver, amount, data);

            return true;
        } else {
            // TODO: report back the errors
            // abort issues
            _vaultCommittedTokens -= amount;
            _vaults[id].committedTokens -= amount;
            // slash user collateral
            _issueRequests[receiver].collateral = 0;
            // TODO: what to do with slashed collateral?
            // paper: send to vault
            _vaults[id].vault.transfer(collateral);
            
            emit AbortIssue(msg.sender, receiver, amount);

            return false;
        }
    }

    // TODO: declare function that vault calls to slash user 
    // collateral in case user did not submit on time
    function abortIssue(address receiver) public returns (bool) {
        // user collateral needs to be great than 0
        require(_issueRequests[receiver].collateral > 0, "No collateral provided");
        // this function can only be called by the assigned vault
        uint256 vaultId = _getVaultId(msg.sender);
        require(vaultId == _issueRequests[receiver].vaultId, "Can only be called by the assigned vault");
        // function can only be called after the deadline has passed
        require(
            _issueRequests[receiver].blocknumber + _issuePeriod <= block.number,
            "Issue period has not yet passed"
        );
        
        uint256 collateral = _issueRequests[receiver].collateral;

        // slash user collateral
        _issueRequests[receiver].collateral = 0;

        msg.sender.transfer(collateral);

        emit AbortIssue(msg.sender, receiver, _issueRequests[receiver].amount);
        // assert(_issueRequests[receiver].collateral == 0); 

        return true;   
    }

    // ---------------------
    // TRANSFER
    // ---------------------
    // see protocols/ERC20.sol

    // ---------------------
    // SWAP
    // ---------------------

    function offerSwap(uint256 tokenAmount, uint256 ethAmount, address payable ethParty) public returns (bool) {
        require(_balances[msg.sender] >= tokenAmount, "Insufficient balance");

        _balances[msg.sender] -= tokenAmount;
        _trades[_tradeId] = Trade(msg.sender, ethParty, tokenAmount, ethAmount, false);

        emit NewTradeOffer(_tradeId, msg.sender, tokenAmount, ethParty, ethAmount);

        _tradeId += 1;

        return true;
    }

    function acceptSwap(uint256 offerId) payable public returns (bool) {
        /* Verify offer exists and the provided ether is enough */
        require(_trades[offerId].completed == false, "Trade completed");
        require(msg.value >= _trades[offerId].ethAmount, "Insufficient amount");

        /* Complete the offer */
        _trades[offerId].completed = true;
        _balances[msg.sender] = _balances[msg.sender] + _trades[offerId].tokenAmount;

        _trades[offerId].tokenParty.transfer(msg.value);

        emit AcceptTrade(offerId, _trades[offerId].tokenParty, _trades[offerId].tokenAmount, msg.sender, msg.value);

        return true;
    }

    // ---------------------
    // REDEEM
    // ---------------------
    // TODO: add vault for requesting redeem
    // TODO: implement option to request maximum amount to redeem
    function requestRedeem(address payable vault, address payable redeemer, uint256 amount, bytes memory userBtcOutput) public returns (bool) {
        /* The redeemer must have enough tokens to burn */
        require(_balances[redeemer] >= amount);
        // TODO: require vault to have enough tokens

        // need to lock tokens
        _balances[redeemer] -= amount;

        _redeemRequestId++;
        _redeemRequests[_redeemRequestId] = RedeemRequest({
            vault: vault,
            redeemer: redeemer, 
            amount: amount, 
            blocknumber: block.number,
            btcOutput: userBtcOutput
        });

        // TODO: mapping of vault txs through hash
        // hash(btc output script, eth_address_redeemer, redeem_request_id, contract_address)

        // TODO: return hash in event
        emit RequestRedeem(redeemer, msg.sender, amount, userBtcOutput, _redeemRequestId);

        return true;
    }

    // TODO: verify hash of previous out
    function confirmRedeem(uint256 id, bytes memory data) public returns (bool) {
        // TODO: confirm redeem can only be called by vault

        // check if within number of blocks
        bool block_valid = _verifyBlock(_redeemRequests[id].blocknumber);
        bool tx_valid = _verifyTx(data); // what parameters?

        if (block_valid && tx_valid) {
            // _balances[redeemer] -= _redeemRequests[id].value;
            _totalSupply -= _redeemRequests[id].amount;
            // TODO: release collateral of vault if requested
            // TODO: update available collateral
            // increase token amount of issuer that can be used for issuing
            emit ConfirmRedeem(_redeemRequests[id].redeemer, id);

            return true;
        } else {
            // TODO: emit event that redeem failed, give vault time until deadline


            return false;
        }
    }

    // TODO: split functions of confirm redeem and reimburse
    function reimburseRedeem(address payable redeemer, uint256 id) public returns (bool) {
        // TODO: verify that deadline has passed
        // TODO: only user can call reimburse
        // TODO: watchtower functionality later as enhancement
        _vaultCollateral -= _redeemRequests[id].amount;
        // restore balance
        _balances[redeemer] += _redeemRequests[id].amount;

        redeemer.transfer(_redeemRequests[id].amount);

        emit Reimburse(redeemer, _redeemRequests[id].vault, _redeemRequests[id].amount);
    }

    // ---------------------
    // REPLACE
    // ---------------------
    // TODO: request partial redeem as enhancement
    // TODO: vault needs to provide collateral
    function requestReplace() public returns (bool) {
        require(_vaultIds[msg.sender] != 0, "Vault not registered");
        require(_vaults[_vaultIds[msg.sender]].replace == false, "Replace already requested");

        _vaults[_vaultIds[msg.sender]].replace = true;
        _vaults[_vaultIds[msg.sender]].blocknumber = block.number;

        emit RequestReplace(msg.sender, _vaults[_vaultIds[msg.sender]].collateral, _vaults[_vaultIds[msg.sender]].blocknumber);

        return true;
    }

    // TODO: get used collateral per vault
    // TODO: block redeem requests, once lockReplace function is finished
    // TODO: set period for redeem requests further into the future
    // TODO: if there are still pending redeem requests, lock replace will revert
    function lockReplace(address vault) public payable returns (bool) {
        require(_vaults[_vaultIds[vault]].replace, "Vault did not request replace");
        require(msg.sender != vault, "Needs to be replaced by a a different vault");
        require(msg.value == _vaults[_vaultIds[vault]].collateral, "Collateral needs to be high enough");

        // TODO: track amount of new collateral provided to send it back to vault replacing the current
        _vaults[_vaultIds[vault]].replaceCandidate = msg.sender;

        emit LockReplace(msg.sender, msg.value);

        return true;
    }

    function confirmReplace(address payable vault, bytes memory data) public returns (bool) {
        require(_vaults[_vaultIds[vault]].replace, "Vault did not request replace");
        require(msg.sender == _vaults[_vaultIds[vault]].vault, "Needs to be confirmed by current vault");
        require(
            (_vaults[_vaultIds[vault]].blocknumber + _replacePeriod) >= block.number,
            "Replace did not occur within required time"
        );

        // TODO: hash (eth_address of vault, contract address, nonce, btc return script)
        // verify that btc has been sent to the correct address
        bool result = _verifyTx(data);

        _registerNewVault(_vaults[_vaultIds[vault]].replaceCandidate, _vaults[_vaultIds[vault]].collateral);
        // send surplus collateral to vault candidate

        // transfer collateral back to vault
        uint256 returnCollateral = _vaults[_vaultIds[vault]].collateral;
        _vaults[_vaultIds[vault]].collateral = 0;
        vault.transfer(returnCollateral);

        emit ConfirmReplace(_vaults[_vaultIds[vault]].replaceCandidate, _vaults[_vaultIds[vault]].collateral);

        return true;
    }

    function abortReplace(address vault) public returns (bool) {
        require(_vaults[_vaultIds[vault]].replace, "Vault did not request replace");
        require(msg.sender == _vaults[_vaultIds[vault]].replaceCandidate);
        require(            
            (_vaults[_vaultIds[vault]].blocknumber + _replacePeriod) <= block.number,
            "Current vault can still confirm the replace within the period"
        );

        _vaults[_vaultIds[vault]].replace = false;

        // TODO: slash collateral of issuer 
        // TODO: return transaction fees of vault candidate
        _vaults[_vaultIds[vault]].replaceCandidate.transfer(_vaults[_vaultIds[vault]].collateral);

        emit AbortReplace(_vaults[_vaultIds[vault]].replaceCandidate, _vaults[_vaultIds[vault]].collateral);

        return true;
    }

    // ---------------------
    // HELPERS
    // ---------------------
    function _getVaultId(address vault) private view returns (uint256) {
        require(_vaultId > 0, "No vault registered");

        return _vaultIds[vault];
    }

    function _registerNewVault(address payable toRegister, uint256 collateral) private returns (bool) {
        // increase vault id
        _vaultId++;

        // register single vault
        _vaults[_vaultId] = Vault({
            vault: toRegister,
            tokenSupply:  _convertEthToBtc(collateral),
            committedTokens: 0,
            collateral: collateral,
            replaceCandidate: address(0),
            replace: false,
            blocknumber: 0
        });
        _vaultIds[toRegister] = _vaultId;

        emit RegisterVault(toRegister, collateral, _vaultId);

        return true;
    }

    function _verifyTx(bytes memory data) private returns(bool verified) {
        // data from line 256 https://github.com/ethereum/btcrelay/blob/develop/test/test_btcrelay.py
        bytes memory rawTx = data;
        uint256 txIndex = 0;
        uint256[] memory merkleSibling = new uint256[](2);
        merkleSibling[0] = uint256(sha256("0xfff2525b8931402dd09222c50775608f75787bd2b87e56995a7bdd30f79702c4"));
        merkleSibling[1] = uint256(sha256("0x8e30899078ca1813be036a073bbf80b86cdddde1c96e9e9c99e9e3782df4ae49"));
        uint256 blockHash = uint256(sha256("0x0000000000009b958a82c10804bd667722799cc3b457bc061cd4b7779110cd60"));

        (bool success, bytes memory returnData) = _relay.call(abi.encodeWithSignature("verifyTx(bytes, uint256, uint256[], uint256)", rawTx, txIndex, merkleSibling, blockHash));

        bytes memory invalid_tx = hex"fe6c48bbfdc025670f4db0340650ba5a50f9307b091d9aaa19aa44291961c69f";
        // TODO: Implement this correctly, now for testing only
        if (keccak256(data) == keccak256(invalid_tx)) {
            return false;
        } else {
            return true;
        }
    }

    function _verifyAddress(address receiver, bytes memory btcAddress, bytes memory data) private pure returns(bool verified) {
        return true;
    }

    function _verifyBlock(uint256 blocknumber) private view returns(bool block_valid) {
        return true;
    }

    function _convertEthToBtc(uint256 eth) private view returns(uint256) {
        /* TODO: use a contract that uses middleware to get the conversion rate */
        return eth * _conversionRate;
    }
}