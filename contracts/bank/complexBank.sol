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

contract ComplexBank is Pausable {
    using SafeMath for uint256;
    address tokenAddress;
    token libreToken;
    

    function ComplexBank() {
        // Do something 
    }

    // 02-queue start
    enum orderType { buy, sell}
    struct OrderData {
        address clientAddress;
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
   function cancelBuyOrder(uint256 _orderID) private {
       require(buyOrders[_orderID].clientAddress != 0x0);
       buyOrders[_orderID].clientAddress.transfer(buyOrders[_orderID].orderAmount);
       buyOrders[_orderID].clientAddress = 0x0;
   }
    
   // Используется внутри в случае если не срабатывают условия ордеров 
   function cancelSellOrder(uint256 _orderID) private {
        require(sellOrders[_orderID].clientAddress != 0x0);
        libreToken.mint(sellOrders[_orderID].clientAddress, sellOrders[_orderID].orderAmount);
        sellOrders[_orderID].clientAddress = 0x0;
    }
    // 02-queue end


    // admin start
    // C идеологической точки зрения давать такие привилегии админу может быть неправиьно
    function cancelBuyOrderAdm(uint256 _orderID) public onlyOwner {
        cancelBuyOrder(_orderID);
    }

    function cancelSellOrderAdm(uint256 _orderID) public onlyOwner {
        cancelSellOrder(_orderID);
    }
    // admin end



}