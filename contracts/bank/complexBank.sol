pragma solidity ^0.4.10;

import "../zeppelin/math/SafeMath.sol";
import "../zeppelin/lifecycle/Pausable.sol";

interface token {
    function balanceOf(address _owner) public returns (uint256);
    function mint(address _to, uint256 _amount) public;
    function getTokensAmount() public returns(uint256);
    function burn(address _burner, uint256 _value) public;
    function setBankAddress(address _bankAddress) public;
}

interface oracleInterface {
    function updateRate() payable public returns (bytes32);
    function getName() constant public returns (bytes32);
    function setBank(address _bankAddress) public;
    function hasReceivedRate() public returns (bool);
}


contract ComplexBank is Pausable {
    using SafeMath for uint256;
    address tokenAddress;
    token libreToken;

    event TokensBought(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event TokensSold(address _beneficiar, uint256 tokensAmount, uint256 cryptoAmount);
    event UINTLog(string description, uint256 data);
    event BuyOrderCreated(uint256 amount);
    event SellOrderCreated(uint256 amount);
    event LogBuy(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 buyPrice);
    event LogSell(address clientAddress, uint256 tokenAmount, uint256 cryptoAmount, uint256 sellPrice);
    event OrderQueueGeneral(string description);
    struct Limit {
        uint256 min;
        uint256 max;
    }

    // Limits start
    Limit public buyEther = Limit(0,99999 * 1 ether);
    Limit public sellTokens = Limit(0,99999);
    // Limits end

    function ComplexBank() {
        // Do something 
    }

    // 01-emission start
    function createBuyOrder(address beneficiary,uint256 rateLimit) public {
        require((msg.value > buyEther.min) && (msg.value < buyEther.max));
        OrderData currentOrder = OrderData({
            senderAddress:msg.sender,
            recipientAddress: beneficiary, 
            orderAmount: msg.value, 
            orderTimestamp: now, 
            rateLimit: rateLimit
        });
        addOrderToQueue(orderType.buy,currentOrder);
    }

    function createSellOrder(uint256 _tokensCount, uint256 _rateLimit) public {
    require((_tokensCount > sellTokens.min) && (_tokensCount < sellTokens.max));
    require(_tokensCount <= libreToken.balanceOf(msg.sender));
    OrderData currentOrder = OrderData({
        senderAddress:msg.sender,
        recipientAddress: msg.sender, 
        orderAmount: _tokensCount, 
        orderTimestamp: now, 
        rateLimit: _rateLimit
    });
    addOrderToQueue(orderType.sell,currentOrder);
    libreToken.burn(msg.sender, _tokensCount);
    SellOrderCreated(_tokensCount); // TODO: maybe add beneficiary?
    }
    // 01-emission end

    // 02-queue start
    enum orderType { buy, sell}
    struct OrderData {
        address senderAddress;
        address recipientAddress;
        uint256 orderAmount;
        uint256 orderTimestamp;
        uint256 rateLimit;
    }


    OrderData[] buyOrders; // очередь ордеров на покупку
    OrderData[] sellOrders; // очередь ордеров на покупку

    function addOrderToQueue(orderType typeOrder, OrderData order) internal {
        if (typeOrder == orderType.buy) {
            buyOrders.push(order);
        } else {
            sellOrders.push(order);
        }
    }
   // Используется внутри в случае если не срабатывают условия ордеров 

   function cancelBuyOrder(uint256 _orderID) private returns (bool) {
        if (buyOrders[_orderID].recipientAddress != 0x0) 
            return false;
        bool sent = buyOrders[_orderID].recipientAddress.send(buyOrders[_orderID].orderAmount);
        if (sent) {
            buyOrders[_orderID].recipientAddress = 0x0;
        } else {
            return false;
        }
    }
    
   // Используется внутри в случае если не срабатывают условия ордеров 
   function cancelSellOrder(uint256 _orderID) private returns(bool) {
        if (sellOrders[_orderID].recipientAddress == 0x0) { 
            return false;
        }
        libreToken.mint(sellOrders[_orderID].senderAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].recipientAddress = 0x0;
        return true;
    }

    //TODO: добавить обработку очереди по N ордеров

    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправиьно
    function cancelBuyOrderAdm(uint256 _orderID) public onlyOwner {
        cancelBuyOrder(_orderID);
    }

    function cancelSellOrderAdm(uint256 _orderID) public onlyOwner {
        cancelSellOrder(_orderID);
    }

    
    /**
     * @dev Attaches token contract.
     * @param _tokenAddress The token address.
     */
    function attachToken(address _tokenAddress) public onlyOwner {
        tokenAddress = _tokenAddress;
        libreToken = token(tokenAddress);
        libreToken.setBankAddress(address(this));
    }

    // admin end


    // 03-oracles methods start
    event InsufficientOracleData(string description, uint256 oracleCount);
    event OraclizeStatus(address indexed _address, bytes32 oraclesName, string description);
    event OraclesTouched(string description);
    event OracleAdded(address indexed _address, bytes32 name);
    event OracleEnabled(address indexed _address, bytes32 name);
    event OracleDisabled(address indexed _address, bytes32 name);
    event OracleDeleted(address indexed _address, bytes32 name);
    event OracleTouched(address indexed _address, bytes32 name);
    event OracleCallback(address indexed _address, bytes32 name, uint256 result);
    event TextLog(string data);

    struct OracleData {
        bytes32 name;
        uint256 rating;
        bool enabled;
        //bool waiting;
        bytes32 queryId;
        uint256 updateTime; // time of callback
        uint256 cryptoFiatRate; // exchange rate
        uint listPointer; // чтобы знать по какому индексу удалять из массива oracleAddresses
    }

    mapping (address=>OracleData) oracles;
    address[] oracleAddresses;
    uint constant MAX_ORACLE_RATING = 10000;
    uint256 public numWaitingOracles; // Maybe use view function instead?
    uint256 public numEnabledOracles; // Maybe use view function instead?

    function getOracleCount() public view returns (uint) {
        return oracleAddresses.length;
    }

    function isOracle(address _oracle) returns (bool) {
        for (uint i = 0; i < oracleAddresses.length; i++) {
            if ( oracleAddresses[i] == _oracle ) 
                return true;
        }
        return false;
        // TODO: rewrote to use mapping() instead cycle
    }
    
    /**
     * @dev Adds an oracle.
     * @param _address The oracle address.
     */
    function addOracle(address _address) public onlyOwner {
        require(_address != 0x0 && !isOracle (_address));
        oracleInterface currentOracle = oracleInterface(_address);
        
        currentOracle.setBank(address(this));
        bytes32 oracleName = currentOracle.getName();
        OracleData memory newOracle = OracleData({
            name: oracleName, 
            rating: MAX_ORACLE_RATING.div(2), 
            enabled: true, 
            queryId: 0, 
            updateTime: 0, 
            cryptoFiatRate: 0, 
            listPointer: 0
        });
        oracles[_address] = newOracle;
        oracleAddresses.push(_address);
        OracleAdded(_address, oracleName);
    }

    /**
     * @dev Disable oracle.
     * @param _address The oracle address.
     */
    function disableOracle(address _address) public onlyOwner {
        require(isOracle(_address) && oracles[_address].enabled == true);
        oracles[_address].enabled = false;
        OracleDisabled(_address, oracles[_address].name);
    }

    /**
     * @dev Enable oracle.
     * @param _address The oracle address.
     */
    function enableOracle(address _address) public onlyOwner {
        require(isOracle(_address) && oracles[_address].enabled == false);
        oracles[_address].enabled = true;
        OracleEnabled(_address, oracles[_address].name);
    }

    /**
     * @dev Delete oracle.
     * @param _address The oracle address.
     */
    function deleteOracle(address _address) public onlyOwner {
        require(isOracle(_address));
        OracleDeleted(_address, oracles[_address].name);
        delete oracles[_address];
        for(uint i = 0; i < oracleAddresses.length; i++) {
            if (oracleAddresses[i] == _address) {
                delete oracleAddresses[i];
                break;
            }
        } // TODO: rewrote without cycle
    }
    
    /**
     * @dev Gets oracle rating.
     * @param _address The oracle address.
     */
    function getOracleRating(address _address) internal view returns(uint256) {
        return oracles[_address].rating;
    }

    /**
     * @dev Set oracle rating.
     * @param _address The oracle address.
     * @param _rating Value of rating
     */
    function setOracleRating(address _address, uint256 _rating) internal {
        require(isOracle(_address) && _rating > 0 && _rating <= MAX_ORACLE_RATING);
        oracles[_address].rating = _rating;
    }

    /**
     * @dev Gets oracle crypto-fiat rate.
     * @param _address The oracle address.
     */
    function getOracleRate(address _address) internal view returns(uint256) {
        return oracles[_address].cryptoFiatRate;
    }

    function fundOracles(uint256 sumToFund) public payable onlyOwner {
        for (uint256 i = 0; i < oracleAddresses.length; i++) {
            if (oracles[oracleAddresses[i]].enabled == false) continue; // Ignore disabled oracles

            if (oracleAddresses[i].balance < sumToFund) {
               oracleAddresses[i].transfer(sumToFund - oracleAddresses[i].balance);
            }
        } // foreach oracles
    }


    // 03-oracles methods end


    // 04-spread calc start 

    // 04-spread calc end


    // sytem methods start


    /**
     * @dev Returns total tokens count.
     */
    function totalTokenCount() public view returns (uint256) {
        return libreToken.getTokensAmount();
    }

    // system methods end



}