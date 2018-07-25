pragma solidity ^0.4.24;

/// @title ERCXXX ReferenceToken Contract
/// @author Dominik Harz
/// @dev This token contract's goal is to give an example implementation
///  of ERCXXX with ERC223 compatible.
///  This contract does not define any standard, but can be taken as a reference
///  implementation in case of any ambiguity into the standard

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { ERCXXX_Base_Interface} from "../ERCXXX_Base_Interface.sol";


contract ERCXXX_SGX_BaseToken is ERCXXX_Base_Interace {
    using SafeMath for uint256;

    // #####################
    // CONTRACT VARIABLES
    // #####################

    string internal name;
    string internal symbol;
    uint256 internal granularity;
    uint256 internal totalSupply;

    uint public contestationPeriod;
    uint public graceRedeemPeriod;

    mapping(address => uint) internal balances;

    address[] internal issuerList;
    mapping(address => bool) internal issuers;

    struct RedeemRequest{
        address redeemer;
        uint value;
        uint redeemTime;
    }

    uint256[] internal redeemRequestList;
    mapping(uint => RedeemRequest) internal redeemRequestMapping;

    // #####################
    // CONSTRUCTOR
    // #####################
    constructor(string _name, string _symbol, uint256 _granularity) internal {
        require(_granularity >= 1);

        name = _name;
        symbol = _symbol;
        granularity = _granularity;
        totalSupply = 0;

        setInterfaceImplementation("ERCXXX_Base_Interace", this);
    }

    // #####################
    // MODIFIERS
    // #####################

    // #####################
    // HELPER FUNCTIONS
    // #####################

    function name() public view returns (string) {
        return name;
    }

    function symbol() public view returns (string) {
        return symbol;
    }

    function totalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint) {
        return balances[_owner];
    }

    function granularity() public view returns (uint256) {
        return granularity;
    }

    // #####################
    // FUNCTIONS
    // #####################

    function pendingRedeemRequests() public view returns(uint256[]) {
        return redeemRequestList;
    }

    function listIssuers() public view returns(address[]) {
        return issuerList;
    }

    function authorizeIssuer(address _toRegister, bytes _data) public;

    function revokeIssuer(address _toUnlist, bytes _data) public;

    function issue(address _sender, address _receiver, bytes _data) public;

    function transfer(address _sender, address _receiver, bytes _data) public;

    function redeem(address _redeemer,  bytes _data) public;
}