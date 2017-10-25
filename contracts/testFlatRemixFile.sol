

pragma solidity ^0.4.11;


import "github.com/oraclize/ethereum-api/oraclizeAPI_0.4.sol";


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}
contract OracleBase is Ownable, usingOraclize {
    event NewOraclizeQuery(string description);
    // надеюсь, нет ограничений на использование bytes32 в событии. Надо посмотреть, как web3.js это воспримет
    event NewPriceTicker(bytes32 oracleName, uint256 price, uint256 timestamp);

    bytes32 public oracleName;
    bytes16 public oracleType; // Human-readable oracle type e.g ETHUSD
    string public description;
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

    struct OracleConfig {
        string datasource;
        string arguments;
    }

    OracleConfig public config;

    function setDescription(string _description) onlyOwner public {
        description = _description;
    }

    function OracleBase(bytes32 _name, string _datasource, string _arguments, bytes16 _type) public {
        owner = msg.sender;
        oracleName = _name;
        oracleType = _type;
        config.datasource = _datasource;
        config.arguments = _arguments;
        updateCost = 2*oraclize_getPrice(_datasource);
    }


    function update() payable {
        require(this.balance > updateCost);
        bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
        validIds[queryId] = true;
        NewOraclizeQuery("Oraclize query was sent, standing by for the answer...");
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        require (msg.sender == oraclize_cbAddress());
        uint256 currentTime = now;
        // where is parseInt? shall we declare? http://remebit.com/converting-strings-to-integers-in-solidity/
        uint ETHUSD = parseInt(result, 2); // in $ cents
        lastResult = ETHUSD;
        lastResultTimestamp = currentTime;
        delete(validIds[myid]);
        NewPriceTicker(oracleName, ETHUSD, currentTime);
    }

    function getName() constant public returns(bytes32) {
        return oracleName;
    }

    function getType() constant public returns(bytes16) {
        return oracleType;
    }
}



interface bankInterface {
    function oraclesCallback (uint256 value, uint256 timestamp) ;
}

contract OracleKraken is  OracleBase {
//    string public constant name = "Bitfinex Oraclize Async";
//    string public constant oracleType = "ETHUSD";
    address public bankContractAddress;
//    address public owner;
    uint public rate;
    bankInterface bank;
    bytes32 oracleName = "Bitfinex Oraclize Async";
    bytes16 oracleType = "ETHUSD";
    string datasource = "URL";
    // https://bitfinex.readme.io/v1/reference#rest-public-ticker
    string arguments = "json(https://api.bitfinex.com/v1/pubticker/ethusd).mid";
    
    event newOraclizeQuery(string description);
    event newPriceTicker(string price); 
    
    mapping(bytes32=>bool) validIds; // ensure that each query response is processed only once

// закомментил что есть в oracleBase.sol
//    event NewOraclizeQuery(string description);
//    event NewPriceTicker(string price);

/*    struct OracleConfig {
        string datesource;
        string arguments;
    }*/

//    OracleConfig public config;
   
    // такой тип наследования описан: https://github.com/ethereum/wiki/wiki/%5BRussian%5D-%D0%A0%D1%83%D0%BA%D0%BE%D0%B2%D0%BE%D0%B4%D1%81%D1%82%D0%B2%D0%BE-%D0%BF%D0%BE-Solidity#arguments-for-base-constructors
    function OracleKraken() OracleBase(oracleName, datasource, arguments, oracleType) public { //OracleBase(oracleName, datasource, arguments, oracleType)
        owner = msg.sender;

        //bankContractAddress = _bankContract;
       
        
        //config.datasource = datasource;
        // mid - среднее значение между bid и ask у битфинекса, считаю целесообразным
        // https://bitfinex.readme.io/v1/reference#rest-public-ticker
        //config.arguments = arguments;
        // FIXME: enable oraclize_setProof is production
        // разобраться с setProof - что с ним не так? - Дима
        //oraclize_setProof(proofType_TLSNotary);
        update();
    }
    
    function setBank (address _bankContract) public {
        bankContractAddress = _bankContract;
        bank = bankInterface(_bankContract);//0x14D00996c764aAce61b4DFB209Cc85de3555b44b Rinkeby bank address
    }

    // модификатор временно убрал, пока он не реализован
    function update() payable {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            bytes32 queryId = oraclize_query(0, config.datasource, config.arguments);
            validIds[queryId] = true;
        }
    }  
    
    function __callback(bytes32 myid, string result, bytes proof) {
        require(validIds[myid]);
        require(msg.sender == oraclize_cbAddress());
        newPriceTicker(result);
        rate = parseInt(result, 2); // save it in storage as $ cents
        // do something with rate
        delete(validIds[myid]);
        bank.oraclesCallback (rate, now);
    }    
    function donate() payable  {}
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender 


}
    contract libreBank is Ownable {
    
    enum limitType { minUsdRate, maxUsdRate, minTransactionAmount, minTokensAmount, minSellSpread, maxSellSpread, minBuySpread, maxBuySpread }
    event newPriceTicker(string oracleName, string price);
    

    event newCallback ( uint256 _rate, uint256 _time);

    function libreBank() {
        
    }
    function getRate() public {
        
    }
    
    function donate() payable  {}
    function oraclesCallback( uint256 _rate, uint256 _time) {
        newCallback (_rate,  _time);
        
    }
    }


