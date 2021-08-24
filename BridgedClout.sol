pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/security/Pausable.sol";

contract BridgedClout is ERC20, Pausable{

    address public operator;

    bool public bridgeState = true;

    mapping(address => string) private EthToBcltAddressBridge;
    mapping(string => address) private BcltToEthAddressBridge;

    mapping(address => uint) public bridgeRequests;

    mapping(address => uint) public mintRequests;

    event BridgeRequest(address _user, string _payload);
    
    event Burn(string _bcltKey, uint _amount);

    uint public bridgeFee;
    uint public mintFee;
    uint public minimumBurn;

    constructor(address _operator, string memory _bcltKey, uint _bridgeFee, uint _mintFee, uint _minimumBurn) ERC20("BridgedClout", "bCLOUT"){
        operator = _operator;
        bridgeFee = _bridgeFee;
        mintFee = _mintFee;
        minimumBurn = _minimumBurn;
        EthToBcltAddressBridge[_operator] = _bcltKey;
        BcltToEthAddressBridge[_bcltKey] = _operator;
    }

    modifier onlyOperator{
        require(msg.sender == operator, "Must be called by operator.");
        _;
    }

    modifier bridgeOpen{
        require(bridgeState, "The Bridge is Closed.");
        _;
    }

    /**-----  Operator functions ----- **/
    function transferOperator(address _newoperator) public onlyOperator{
        operator = _newoperator;
    }

    function pauseContract() public onlyOperator{
        _pause();
    }

    function unpauseContract() public onlyOperator{
        _unpause();
    }

    function openBridge() public onlyOperator{
        bridgeState = true;
    }

    function closeBridge() public onlyOperator{
        bridgeState = false;
    }

    function setBridgeFee(uint _fee) public onlyOperator{
        bridgeFee = _fee;
    }

    function setMintFee(uint _fee) public onlyOperator{
        mintFee = _fee;
    }

    function bridgeUser(string memory _bcltKey, address _ethAddress) public onlyOperator{
        delete bridgeRequests[_ethAddress];
        EthToBcltAddressBridge[_ethAddress] = _bcltKey;
        BcltToEthAddressBridge[_bcltKey] = _ethAddress;
    }

    function mint(string memory _bcltKey, uint _amount) public onlyOperator{
        delete mintRequests[BcltToEthAddressBridge[_bcltKey]];
        _mint(BcltToEthAddressBridge[_bcltKey], _amount);
    }

    /**----- User functions -----**/
    function bridgeRequest(string memory _payload) public payable bridgeOpen{
        require(!userBridged(EthToBcltAddressBridge[msg.sender]), "User Already Bridged.");
        require(msg.value >= bridgeFee, "Invalid Bridge Fee.");
        require(bridgeRequests[msg.sender] == 0, "Already made a bridge request.");
        bridgeRequests[msg.sender] = msg.value;
        emit BridgeRequest(msg.sender, _payload);
    }

    function removeBridgeRequest() public bridgeOpen{
        delete bridgeRequests[msg.sender];
    }

    function mintRequest() public payable bridgeOpen{
        require(userBridged(EthToBcltAddressBridge[msg.sender]), "User not Bridged.");
        require(msg.value >= mintFee, "Invalid sender mint fee.");
        require(mintRequests[msg.sender] == 0, "Already made a mint request");
        mintRequests[msg.sender]  = msg.value;
    }

    function removeMintRequest() public bridgeOpen{
        delete mintRequests[msg.sender];
    }

    function burn(uint256 _amount) public payable bridgeOpen{
        require(userBridged(EthToBcltAddressBridge[msg.sender]), "User is not Bridged.");
        require(_amount >= minimumBurn, "Burn transfer amount was to low.");
        _burn(msg.sender, _amount);
        emit Burn(EthToBcltAddressBridge[msg.sender], _amount);
    }

    function unbridgeUser() public{
        require(userBridged(EthToBcltAddressBridge[msg.sender]), "User Not Bridged.");
        require(mintRequests[msg.sender] == 0, "Pending mint request.");
        delete BcltToEthAddressBridge[EthToBcltAddressBridge[msg.sender]];
        delete EthToBcltAddressBridge[msg.sender];
    }

    //  Helper functions
    function claimFees() public {
        payable(operator).transfer(address(this).balance);
    }

    function userBridged(string memory _bcltAddress) public view returns (bool _bridged){
        return BcltToEthAddressBridge[_bcltAddress] == address(0) ? false : true;
    }
    
    function userBridged()  public view returns(bool _bridged){
        return bytes(EthToBcltAddressBridge[msg.sender]).length == 0 ? false : true;
    }

    function viewBridgeRequest(address _user) public view returns(uint _requestFee){
        return bridgeRequests[_user];
    }

    function viewMintRequest(string memory _bcltKey) public view returns(uint _requestFee){
        return mintRequests[BcltToEthAddressBridge[_bcltKey]];
    }

    function viewMintRequest() public view returns(uint _requestFee){
        return mintRequests[msg.sender];
    }

    function bcltToEthAddress(string memory _bcltKey) public view returns(address _userAddress){
        return BcltToEthAddressBridge[_bcltKey];
    } 

    function ethToBcltAddress() public view returns(string memory _bcltAddress){
        return EthToBcltAddressBridge[msg.sender];
    }

    function getBalance(string memory _account) public view returns(uint _balance){
        return balanceOf(BcltToEthAddressBridge[_account]);
    }

    function decimals() public pure override returns(uint8){
        return 9;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "ERC20Pausable: token transfer while paused");
    }
}