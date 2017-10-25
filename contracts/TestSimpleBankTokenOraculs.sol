pragma solidity ^0.4.11;


import "github.com/oraclize/ethereum-api/oraclizeAPI_0.4.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/math/SafeMath.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/ownership/Ownable.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/PausableToken.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/MintableToken.sol";
// Основной файл банка

// ТОКЕН

/**
 * @title LibreCoin contract.
 *
 * @dev ERC20 Coin contract.
 */
contract LibreCoin is MintableToken, PausableToken {
    string public version = "0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    address public bankContract;

    event Burn(address indexed burner, uint256 value);
    event Mint(address indexed burner, uint256 value);

    modifier onlyBank() {
        require(msg.sender == bankContract);
        _;
    }

    function LibreCoin() public {
        totalSupply = 0;
        owner = msg.sender;
        mint(msg.sender, 1000);
        
    }
    
    /**
     * @dev Returns total coin supply.
     */
    function getTokensAmount() public constant returns(uint256) {
        return totalSupply;
    }

    /**
     * @dev Sets new bank address.
     * @param _bankContractAddress The bank address.
     */
    function setBankAddress(address _bankContractAddress) onlyOwner public /*private*/ {
        require(_bankContractAddress != 0x0);
        bankContract = _bankContractAddress;
    }

    // только для тестов
    function toString(address x) returns (string) {
        bytes memory b = new bytes(20);
        for (uint i = 0; i < 20; i++)
            b[i] = byte(uint8(uint(x) / (2**(8*(19 - i)))));
        return string(b);
    }
    function getBankAddress() constant public returns (string) {
        string memory returnValue = toString(bankContract);
        return returnValue;
    }
    // конец временного фрагмента для тестов

      /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(address _to, uint256 _amount) canMint  public returns (bool){
    totalSupply = totalSupply.add(_amount);
    balances[_to] = balances[_to].add(_amount);
    Mint(_to, _amount);
    Transfer(0x0, _to, _amount);
    return true;
  }


    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(address burner, uint256 _value)  public {
        require(_value > 0);
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }

}

interface token {
    /*function transfer(address receiver, uint amount);*/
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to,uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address burner, uint256 _value) public;
}


interface oracleInterface {
    function update() public;
    function getName() constant public returns(bytes32);
}

/**
 * @title SimplexBank.
 *
 * @dev Bank contract.
 */
contract SimplexBank {
    using SafeMath for uint256;
    event Log(string anything);
    event Log(address addr, string anything);
    event Log(address addr, uint256 value1, uint256 value2);

    token libreToken;

    uint256 public dummy = 666;

    uint256 public rate = 1000;
    
    function setToken(address _tokenContract) public {
        libreToken = token(_tokenContract);
    }

    function setDummy(uint256 _value) public {
        dummy = _value;
    }

    function getDummy() public view returns (uint256) {
        return dummy;
    }


    function SimplexBank() public {
    }

    /**
     * @dev Receives donations.
     */
    function donate() payable public {}

    /**
     * @dev Gets total tokens count.
     */
    function totalTokenCount() public returns (uint256) {
        return libreToken.getTokensAmount();
    }

    /**
     * @dev Transfers crypto.
     */
   function withdrawCrypto(address _beneficiar) public {
        _beneficiar.transfer(this.balance);
    }

    function () payable external {
        buyTokens(msg.sender);
    }
    function buy () payable public { // Добавил для лентяев
        buyTokens(msg.sender);
    }

    /**
     * @dev Lets user buy tokens.
     * @param _beneficiar The buyer's address.
     */
    function buyTokens(address _beneficiar) payable public {
        require(_beneficiar != 0x0);
        uint256 tokensAmount = msg.value.mul(rate).div(100);  
        libreToken.mint(_beneficiar, tokensAmount);
        Log(_beneficiar, tokensAmount, msg.value);
    }

    /**
     * @dev Lets user sell tokens.
     * @param _amount The amount of tokens.
     */
    function sellTokens(uint256 _amount) public {
        require (libreToken.balanceOf(msg.sender) >= _amount);        // checks if the sender has enough to sell
        
        uint256 tokensAmount;
        uint256 cryptoAmount = _amount.div(rate).mul(100);
        if (cryptoAmount > this.balance) {                  // checks if the bank has enough Ethers to send
            tokensAmount = this.balance.mul(rate).div(100); // нужна дополнительная проверка, на случай повторного запроса при пустых резервах банка
            cryptoAmount = this.balance;
        } else {
            tokensAmount = _amount;
        }
        msg.sender.transfer(cryptoAmount);
        libreToken.burn(msg.sender, tokensAmount); 
        Log(msg.sender, tokensAmount, cryptoAmount);
    }
}
// ОРАКУЛЫ
contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    // надеюсь, нет ограничений на использование bytes32 в событии. Надо посмотреть, как web3.js это воспримет
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);
    event newOraclizeQuery(string description);
    event newPriceTicker(string price); 

    bytes32 public oracleName = "Base Oracle";
    bytes16 public oracleType = "Undefined"; // Human-readable oracle type e.g ETHUSD
    string public description;
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once
    address public bankContractAddress;
    uint public rate;
    bankInterface bank;
    // пока не знаю, надо ли. добавил как флаг для тестов
    bool public receivedRate = false;
    uint256 MIN_UPDATE_TIME = 5 minutes;

    // --debug section--
        address public oracleCallbacker;
    // --/debug section--

    modifier onlyBank() {
        require(msg.sender == bankContractAddress);
        _;
    }

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    OracleConfig public oracleConfig;

    function hasReceivedRate() public returns (bool) {
        return receivedRate;
    }

    function OracleBase() public {
        owner = msg.sender;
        oraclize_setProof(proofType_TLSNotary | proofStorage_IPFS);
    }

    /**
     * @dev Sets oracle description.
     * @param _description Description.
     */
    function setDescription(string _description) onlyOwner public {
        description = _description;
    }

    function setBank(address _bankContract) public {
        bankContractAddress = _bankContract;
        //bank = bankInterface(_bankContract);//0x14D00996c764aAce61b4DFB209Cc85de3555b44b Rinkeby bank address
    }

    function updateRate() payable public /*onlyBank*/ {
        // для тестов отдельно оракула закомментировал след. строку
        //require (msg.sender == bankContractAddress);
        require (now > lastResultTimestamp + MIN_UPDATE_TIME);
        receivedRate = false;
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            bytes32 queryId = oraclize_query(0, oracleConfig.datasource, oracleConfig.arguments);
            newOraclizeQuery("Oraclize query was sent, standing by for the answer...");
            validIds[queryId] = true;
        }
    }  
    
    /**
    * @dev Oraclize default callback with set proof
    */
   function __callback(bytes32 myid, string result, bytes proof) public {
        require(validIds[myid]);
        newOraclizeQuery("__callback proof here!");
        oracleCallbacker = msg.sender;
        require(msg.sender == oraclize_cbAddress());
        receivedRate = true;
        newPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        // do something with rate
        delete(validIds[myid]);
        lastResultTimestamp = now;
        bank.oraclesCallback(bankContractAddress, rate, now);
    }

    /**
     * @dev Updates oraclize costs.
     * Shall run after datasource setting.
     */
    function updateCosts() internal {
        updateCost = 2 * oraclize_getPrice(oracleConfig.datasource);
    }

    function getName() constant public returns(bytes32) {
        return oracleName;
    }

    function getType() constant public returns(bytes16) {
        return oracleType;
    }
}
// ОРАКУЛЫ
contract OracleBitfinex is OracleBase {
    bytes32 constant ORACLE_NAME = "Bitfinex Oraclize Async";
    bytes16 constant ORACLE_TYPE = "ETHUSD";
    string constant ORACLE_DATASOURCE = "URL";
    // https://bitfinex.readme.io/v1/reference#rest-public-ticker
    string constant ORACLE_ARGUMENTS = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
    
    function OracleBitfinex(address _bankContract) public {
        oracleName = ORACLE_NAME;
        oracleType = ORACLE_TYPE;
        oracleConfig = OracleConfig({datasource: ORACLE_DATASOURCE, arguments: ORACLE_ARGUMENTS});
        bankContractAddress = _bankContract;
        updateCosts();
    }
        
    function donate() payable { }
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 
}



interface bankInterface {
    function oraclesCallback(address _address, uint256 value, uint256 timestamp) public;
}

