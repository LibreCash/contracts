pragma solidity ^0.4.10;

import "./zeppelin/math/SafeMath.sol";

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

    uint256 rate = 1000;

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        bool waiting;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
    }
    OracleData oracle;
    address oracleAddress;

    uint constant MAX_ORACLE_RATING = 10000;

    function SimplexBank(address _tokenContract) public {
        libreToken = token(_tokenContract);
    }

    function setOracle(address _address) public {
        require(_address != 0x0);
        oracleAddress = _address;
        oracleInterface currentOracleInterface = oracleInterface(_address);

        OracleData memory thisOracle = OracleData({name: currentOracleInterface.getName(), rating: MAX_ORACLE_RATING.div(2), 
                                                    enabled: true, waiting: false, updateTime: 0, cryptoFiatRate: 0});
        oracle = thisOracle;
    }

    function getOracleRating() public view returns (uint256) {
        return oracle.rating;
    }

    function getRate() public view returns (uint256) {
        return rate;
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

    function oraclesCallback(address _address, uint256 _rate, uint256 _time) public {
        oracle.cryptoFiatRate = _rate;
        oracle.updateTime = _time;
        oracle.waiting = false;
        rate = _rate;
    }




}