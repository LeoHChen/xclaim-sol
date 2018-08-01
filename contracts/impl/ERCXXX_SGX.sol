pragma solidity ^0.4.24;

/// @title ERCXXX ReferenceToken Contract
/// @author Dominik Harz
/// @dev This token contract's goal is to give an example implementation
///  of ERCXXX with ERC20 compatibility.
///  This contract does not define any standard, but can be taken as a reference
///  implementation in case of any ambiguity into the standard
import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../ERCXXX_Base_Interface.sol";


contract ERCXXX_SGX is ERCXXX_Base_Interface {
    using SafeMath for uint256;

    // #####################
    // CONTRACT VARIABLES
    // #####################


    string public name;
    string public symbol;
    uint256 public granularity;
    uint256 public totalSupply;

    uint256 public contestationPeriod;
    uint256 public graceRedeemPeriod;
    /* TODO: work out a value for minimum collateral */
    uint256 public minimumCollateral;

    mapping(address => uint) public balances;

    address public issuer;
    // mapping(address => bool) public issuers;

    struct RedeemRequest{
        address redeemer;
        uint value;
        uint redeemTime;
    }

    uint256[] public redeemRequestList;
    mapping(uint => RedeemRequest) public redeemRequestMapping;

    // All events are defined in the interface contract - no need to double it here
    /* Event emitted when a transfer is done */
    // event Transfer(address indexed from, address indexed to, uint256 amount);

    // #####################
    // CONSTRUCTOR
    // #####################
    constructor(string _name, string _symbol, uint256 _granularity) public {
        require(_granularity >= 1);

        name = _name;
        symbol = _symbol;
        granularity = _granularity;
        totalSupply = 0;
        // TODO: value
        contestationPeriod = 1;
        // TODO: value
        graceRedeemPeriod = 1;
        // No collateral for SGX since we fully trust the issuer
        minimumCollateral = 0;
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

    function issuer() public view returns(address) {
        return issuer;
    }

    function authorizeIssuer(address toRegister) public payable {
        require(msg.value >= minimumCollateral);
        require(issuer==address(0));
        issuer = toRegister;

        emit AuthorizedIssuer(toRegister, msg.value);
    }

    function revokeIssuer(address toUnlist) private {
        issuer = address(0);

        emit RevokedIssuer(toUnlist);
    }

    function issue(address receiver, uint256 amount, bytes data) public {
        /* This method can only be called by an Issuer */
        require(msg.sender == issuer);

        balances[receiver] += amount;
        emit Issue(msg.sender, receiver, amount, data);
    }

    function transferFrom(address sender, address receiver, uint256 amount) public {
        require(balances[sender] >= amount);

        balances[sender] = balances[sender] - amount;
        balances[receiver] = balances[receiver] + amount;
        emit Transfer(sender, receiver, amount);
    }

    function redeem(address redeemer, uint256 amount, bytes data) public {
        /* This method can only be called by an Issuer */
        require(msg.sender == issuer);

        /* The redeemer must have enough tokens to burn */
        require(balances[redeemer] >= amount);

        balances[redeemer] -= amount;
        emit Redeem(redeemer, msg.sender, amount, data);
    }
}
