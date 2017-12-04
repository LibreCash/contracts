pragma solidity ^0.4.11;

contract ERC20 {
    string public name = "Token Name";
    string public symbol = "SYM";
    uint8 public constant decimals = 18;
    uint public totalSupply;

    mapping(address => uint) balances;
    mapping (address => mapping (address => uint)) allowed;

    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed owner, address indexed spender, uint value);

    function ERC20(string _name, string _symbol, uint _totalSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply * 10 ** uint(decimals);
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address _owner) constant returns (uint balance) {
        return balances[_owner];
    }

    function transfer(address _to, uint _value) returns (bool) {
        require( (_to != address(0)) &&
                    (balances[msg.sender] >= _value) &&
                    (balances[_to] <= (balances[_to] + _value)));
        
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(address _from, address _to, uint _value) returns (bool) {
        require(_to != address(0) &&
                    (balances[_from] >= _value) &&
                    (balances[_to] <= (balances[_to] + _value)) &&
                    (allowed[_from][msg.sender] >= _value));

        balances[_from] -= _value;
        balances[_to] += _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint remaining) {
        return allowed[_owner][_spender];
    }
}