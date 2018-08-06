pragma solidity ^0.4.24;

/**
* Base ERCXXX Interface
*/
contract ERCXXX_Base_Interface {

    // #####################
    // CONTRACT VARIABLES
    // #####################

    /**
    * Denotes the maximum supply of the backing cryptocurrency.
    */
    // uint public maxSupply;

    /**
    * Total supply that can be issued by this contract.
    * Of only once instance is to be used, set contractSupply = maxSupply
    */
    // uint public contractSupply;

    /**
    * Duration of the contest period - contract will only consider transactions with sufficient confirmations as
    * valid.
    * Optional: add minimum seconds duration as fallback (threat: timestamp tampering)
    */
    // uint public contestationPeriod;

    /**
    * Duration of the grace period, until which the Issuer must have sent the burned tokens to the redeemer d
    * Measured in Ethereum blocks. Optional: add maximum seconds duration as fallback (threat: timestamp tampering)
    */
    // uint public graceRedeemPeriod;

    /**
    * List of user balances.
    */
    // mapping(address => uint) balances;

    /**
    * Struct containing information on a redeem request
    */
    // struct RedeemRequest{
    //    address redeemer;
    //    uint value;
    //    uint redeemTime;
    // }

    /**
    * List of pending redeem requests
    */
    // mapping(uint => RedeemRequest) redeemRequests;


    // #####################
    // MODIFIERS
    // #####################

    // TODO: add modifiers for "ASSERTs" here

    // #####################
    // HELPER FUNCTIONS
    // #####################

    function name() public view returns (string);

    function symbol() public view returns (string);

    function totalSupply() public view returns (uint256);

    function balanceOf(address owner) public view returns (uint);

    // Get the smallest part of the token that’s not divisible.
    // The following rules MUST be applied with respect to the granularity:
    // The granularity value MUST NOT be changed.
    // The granularity value MUST be greater or equal to 1.
    // Any minting, send or burning of tokens MUST be a multiple of the granularity value.
    // Any operation that would result in a balance that’s not a multiple of the granularity value, MUST be considered invalid and the transaction MUST throw.
    // NOTE: Most of the tokens SHOULD be fully partitionable, i.e. this function SHOULD return 1 unless there is a good reason for not allowing any partition of the token.

    function granularity() public view returns (uint256);


    // #####################
    // FUNCTIONS
    // #####################
    function issuer() public view returns(address);

    /**
   * Registers / unlists a new issuer
   * @param toRegister - address to be registered/unlisted
   * data - [OPTIONAL] data, contains issuers address in the backed cryptocurrency and
   *         any other necessary info for validating the issuer
   *
   * ASSERT: sufficient collateral provided
   *
   * CAUTION: may have to be set to private in SGX version, if no modification to issuers is wanted
   * Private won't work - private in Solidity is in the sense of: only the contract can call, not private to specific parties.
   */
    function authorizeIssuer(address toRegister) public payable;

    function revokeIssuer(address toUnlist) private;

    function registerIssue(uint256 amount) public payable; 
    /**
    * Issues new units of cryptocurrency-backed token.
    * @param receiver - ETH address of the receiver, as provided in the 'lock' transaction in the native native currency
    * @param amount - number of issued tokens
    * @param data - data, contains 'lock' transaction [OPTIONAL?]
    * TODO: decide if data this is required. We probably only need the txid
    *
    * ASSERT: msg.sender in relayer list, abort otherwise.
    */
    function issueCol(address receiver, uint256 amount, bytes data) public;

    function registerHTLC(uint256 locktime, uint256 amount, bytes32 script, bytes32 signature, bytes32 data) public;

    function issueHTLC(address receiver, uint256 amount, bytes data) public;

    /**
    * Offer a trade of tokens for ether.
    * @param tokenAmount - amount of tokens to be exchanged
    * @param ethAmount - amount of Ether to be exchanged
    * @param ethParty - user to exchange tokens for ether with
    *
    * ASSERT:
    * -) Sender actually owns the specified tokens.
    */
    function offerTrade(uint256 tokenAmount, uint256 ethAmount, address ethParty) public;

    /**
    * Transfers ownership of tokens to another user. Allows to potentially lock the funds with another issuer.
    * @param sender - sender address
    * @param receiver - receiver address
    * @param amount - data, contains the new 'lock' transaction
    * ASSERT:
    * -) Sender actually owns the specified tokens.
    *
    * TODO: optional checks:
    * -) is the first 'lock' TX still unspent. Will require call to relay.
    * -) does this tx actually spend from the first 'lock' tx correctly. Will require call to relay.
    * -) is the transferred amount high enough to cover native tx fees. Will require call to relay.
    */
    function transfer(address sender, address receiver, uint256 amount) public;

    /**
    * Initiates the redeeming of backed-tokens in the native cryptocurrency. Redeemed tokens are 'burned' in the process.
    * @param redeemer - redeemer address
    * id of the token struct to be redeemed (and hence burned)
    * @param data - data, contains the 'redeem' transaction to be signed by the issuer
    *
    * ASSERT:
    * -) redeemer actually owns the given amount of tokens (including transaction fees in the native blockchain)
    *
    * TODO: optional: add checks - is the first 'lock' TX still unspent and does this tx actually spend from the first 'lock' tx correctly. Will require call to relay.
    */
    function redeem(address redeemer, uint256 amount, bytes data) public;

    // #####################
    // EVENTS
    // #####################

    /**
   * Register Issue revent:
   * @param issuer - ETH address of the newly registered/unlisted issuer
   * @param collateral - provided collateral
   * data - data, contains evtl. necessary data (e.g., lock transaction for native currency collateral)
   */
    event AuthorizedIssuer(address indexed issuer, uint collateral);

    event RevokedIssuer(address indexed issuer);

    event RegisterIssue(address indexed sender, uint256 value, uint256 timelock, uint8 issueType);
    /**
    * Issue event:
    * @param issuer - ETH address of the issuer
    * @param receiver - ETH address of the receiver, as provided in the 'lock' transaction in the native native currency
    * @param value - number of issuer tokens
    * @param data - data, contains 'lock' transaction
    */
    event Issue(address indexed issuer, address indexed receiver, uint value, bytes data);

    event AbortIssue(address indexed issuer, address indexed receiver, uint value, bytes data);

    /**
    * Transfer event:
    * @param sender - ETH address of the sender
    * @param receiver - ETH address of the receiver
    * @param value - transferred value
    */
    event Transfer(address indexed sender, address indexed receiver, uint value);

    /**
    * Trade event:
    * @param transferOfferId - Index of transfer offer completed
    * @param tokenParty - ETH address of the party exchanging tokens
    * @param tokenAmount - amount in tokens transferred
    * @param ethParty - ETH address of the party exchanging Ether
    * @param ethAmount - amount in Ether transferred
    */
    event Trade(uint256 transferOfferId, address indexed tokenParty, uint256 tokenAmount, address indexed ethParty, uint256 ethAmount);

    /**
    * Redeem event:
    * @param redeemer - ETH address of the redeemer
    * @param issuer - ETH address of the issuer
    * @param value - number of tokens to be redeemed (and hence burned)
    * @param data - data, contains 'redeem' transaction (to be signed by the issuer)
    */
    event Redeem(address indexed redeemer, address indexed issuer, uint value, bytes data);

}
