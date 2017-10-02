
pragma solidity ^0.4.0;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";


contract tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData); }
 
/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20Basic {
  uint public totalSupply;
  function balanceOf(address who) constant returns (uint);
  function transfer(address to, uint value);
  event Transfer(address indexed from, address indexed to, uint value);
}

/**
 * Math operations with safety checks
 */
library SafeMath {
  function mul(uint a, uint b) internal returns (uint) {
    uint c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint a, uint b) internal returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal returns (uint) {
    assert(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal returns (uint) {
    uint c = a + b;
    assert(c >= a);
    return c;
  }

  function max64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a >= b ? a : b;
  }

  function min64(uint64 a, uint64 b) internal constant returns (uint64) {
    return a < b ? a : b;
  }

  function max256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a >= b ? a : b;
  }

  function min256(uint256 a, uint256 b) internal constant returns (uint256) {
    return a < b ? a : b;
  }
  
  /**
   * Based on http://www.codecodex.com/wiki/Calculate_an_integer_square_root
   */
  function sqrt(uint num) internal returns (uint) {
    if (0 == num) { // Avoid zero divide 
      return 0; 
    }   
    uint n = (num / 2) + 1;      // Initial estimate, never low  
    uint n1 = (n + (num / n)) / 2;  
    while (n1 < n) {  
      n = n1;  
      n1 = (n + (num / n)) / 2;  
    }  
    return n;  
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances. 
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint;

  mapping(address => uint) balances;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint size) {
     if(msg.data.length < size + 4) {
       throw;
     }
     _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * @return An uint representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint);
  function transferFrom(address from, address to, uint value);
  function approve(address spender, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}

/**
 * @title Standard ERC20 token
 *
 * @dev Implemantation of the basic standart token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is BasicToken, ERC20 {

  mapping (address => mapping (address => uint)) allowed;

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // if (_value > _allowance) throw;

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on beahlf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint _value) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) throw;

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  /**
   * @dev Function to check the amount of tokens than an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}
 

contract LibreCash is StandardToken, usingOraclize {
    
    string public standard = "LibreCashToken 0.1.1";
    string public constant name = "LibreCash Token";
    string public constant symbol = "LCT";
    uint32 public constant decimals = 18;
    
    address public owner1;
    address public owner2;
    
    uint public ETHUSD;
    uint256 public sellPrice;
    uint256 public buyPrice;
    
    mapping (bytes32=>ClientRecord) clients;
    struct ClientRecord {
        bool isBuy;
        address ClientAddress;
        uint256 ClientAmount;
    } 
    
    uint currentQuery = 0;
    Query[] oraclizeQueries;
    struct Query {
        string datasource;
        string argument;
    } 
    
    
    
    uint public sellSpreadInvert = 50;
    uint public buySpreadInvert = 50;
    
    uint256 minEtherAmount = 0;
    uint256 minTokenAmount = 0;
    uint256 public surplusEther;
    
    event newOraclizeQuery(string description);
    event newPriceTicker(string price);
    event LogSell(address Client, uint256 sendTokenAmount, uint256 EtherAmount, uint256 totalSupply);
    event LogBuy(address Client, uint256 TokenAmount, uint256 sendEtherAmount, uint256 totalSupply);
    event LogWhithdrawal (uint256 EtherAmount, address addressTo, uint invertPercentage);
   
   function LibreCash() {
        totalSupply = 0;
        owner1 = msg.sender;
        owner2 = msg.sender;
        oraclizeQueries.length = 2;
        oraclizeQueries[0].datasource = "URL";
        oraclizeQueries[0].argument = "json(https://api.kraken.com/0/public/Ticker?pair=ETHUSD).result.XETHZUSD.c.0";
        oraclizeQueries[1].datasource = "WolframAlpha";
        oraclizeQueries[1].argument = "1 ether per usd";
        // FIXME: enable oraclize_setProof is production
        //oraclize_setProof(proofType_TLSNotary);
    }
    
  /**
     * @dev Throws if called by any account other than one of the owners. 
     */
    modifier onlyOwner() {
      if (msg.sender != owner1 && msg.sender != owner2) {
        throw;
      }
      _;
    }
 
  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner1 The address to transfer ownership to.
   */
  function transferOwnership1(address newOwner1) onlyOwner {
    require(newOwner1 != address(0));      
    owner1 = newOwner1;
  }
  function transferOwnership2(address newOwner2) onlyOwner {
    require(newOwner2 != address(0));      
    owner2 = newOwner2;
  } 
  
    
    
    function SetSpread (uint _sellSpreadInvert, uint _buySpreadInvert) onlyOwner {
    require ((_sellSpreadInvert > 0)&&(_buySpreadInvert > 0));
    sellSpreadInvert = _sellSpreadInvert;
    buySpreadInvert = _buySpreadInvert;
    }
    
    function setminEtherAmount (uint256 _minEtherAmount) onlyOwner {
    minEtherAmount = _minEtherAmount;
    }
    
    function setminTokenAmount (uint256 _minTokenAmount) onlyOwner {
    minTokenAmount = _minTokenAmount;
    }
    
    function setQraclizeQuery (string newQraclizeQuery) onlyOwner {
    //QraclizeQuery = newQraclizeQuery;
    } 
    
    function donate() payable onlyOwner {}
    // Sending ether directly to the contract invokes buy() and assigns tokens to the sender
    function () payable {
        buy();
    }

    // ***************************************************************************

    // Buy token by sending ether here
    //
    // Price is being determined by the algorithm in recalculatePrice()
    // You can also send the ether directly to the contract address   
    
    function buy() payable {
        require (msg.value > minEtherAmount);
        update(0, true, msg.sender, msg.value);  
    }
    
    function buyAfterUpdate (bytes32 queryid, address _address, uint256 _amount) internal {
        uint256 amount = _amount * buyPrice / 100;                // calculates the amount
        totalSupply = totalSupply.add(amount);
        balances[_address] = balances[_address].add(amount);                  // adds the amount to buyer's balance
        Transfer(0x0, this, amount);                // execute an event reflecting the change
        Transfer(this, _address, amount); 
        LogBuy(_address, amount, _amount, totalSupply);
        delete clients[queryid];     
    }

    function sell (uint256 amount) {
        require (balances[msg.sender] >= amount );        // checks if the sender has enough to sell
        require (amount >= minTokenAmount);
        update(0, false, msg.sender, amount);
    }
    
    function sellAfterUpdate (bytes32 queryid, address _address, uint256 _amount) internal {
        uint256 TokenAmount;
        uint256 EtherAmount  = _amount / sellPrice * 100;
        if (EtherAmount > this.balance) {                  // checks if the contract has enough to sell
            TokenAmount = this.balance * sellPrice / 100;
            EtherAmount = this.balance;
        } else {
            TokenAmount = _amount;
            EtherAmount = _amount / sellPrice * 100;
        }
        if (!_address.send(EtherAmount)) {        // sends ether to the seller. It's important
            throw;                                         // to do this last to avoid recursion attacks
        } else {
            totalSupply = totalSupply.sub(TokenAmount);
            balances[msg.sender] -= TokenAmount;                   // subtracts the amount from seller's balance
            Transfer(msg.sender, this, TokenAmount);            // executes an event reflecting on the change
            Transfer(this, 0x0, TokenAmount);            // executes an event reflecting on the change
        }
        LogSell(_address, TokenAmount, EtherAmount, totalSupply); 
        delete clients[queryid]; 
    }
    
    function __callback(bytes32 myid, string result, bytes proof) {if (msg.sender != oraclize_cbAddress()) throw;
        newPriceTicker(result);
        ETHUSD = parseInt(result, 2); // save it in storage as $ cents
        // do something with ETHUSD
        buyPrice = ETHUSD - ETHUSD / buySpreadInvert;
        sellPrice = ETHUSD + ETHUSD / sellSpreadInvert;
        if (this.balance > totalSupply / sellPrice * 100) {
           surplusEther = this.balance - (totalSupply / sellPrice * 100);
        } else {
            surplusEther =0;
        }
        
        if (clients[myid].isBuy) {
            buyAfterUpdate (myid, clients[myid].ClientAddress, clients[myid].ClientAmount);
        } else {
            sellAfterUpdate (myid, clients[myid].ClientAddress, clients[myid].ClientAmount);
        }
        
    }
    
    function update(uint delay, bool _isBuy, address _address, uint256 _amount) payable {
        if (oraclize_getPrice("URL") > this.balance) {
            newOraclizeQuery("Oraclize query was NOT sent, please add some ETH to cover for the query fee");
        } else {
            newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
            bytes32 queryId = oraclize_query(delay, oraclizeQueries[currentQuery].datasource, oraclizeQueries[currentQuery].argument);
            clients[queryId].isBuy = _isBuy;
            clients[queryId].ClientAddress = _address;
            clients[queryId].ClientAmount = _amount;
        }
    }  

    
    function safeWhithdrawal (uint invertPercentage) onlyOwner {
        require (surplusEther > 0); 
        surplusEther = this.balance - (totalSupply / sellPrice * 100);
        msg.sender.send(surplusEther/invertPercentage);
        LogWhithdrawal (surplusEther/invertPercentage, msg.sender, invertPercentage);
         
    }

    
    
}