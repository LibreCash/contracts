import "./oraclizeAPI_0.4.sol";
import "./zeppelin/ownership/Ownable.sol";

contract oracleBase is Ownable,usingOraclize {
    event newPriceTicker(string oracleName, uint256 price, uint256 timestamp);
    string public name;
    string public description;
    uint256 lastResult;
    uint256 lastResultTimestamp;
    uint256 public updateCost;
    address public owner;

    struct oracleConfig {
        string datesource;
        string arguments;
    }

    oracleConfig config;

    function setDescription(string _description) onlyOwner {
        description = _description;
    }

    function oracleBase(string _name, string _datasource, string _arguments) {
        owner = msg.sender;
        name = _name;
        config.datasource = _datasource;
        config.arguments = _arguments;
        updateCost = 2*oraclize_getPrice(_datasource);
    }

    function update(uint delay, uint _BSU, address _address, uint256 _amount, uint _limit) payable {
        require(this.balance > updateCost);
        bytes32 queryId = oraclize_query(delay, config.datasource, config.argument);
        newOraclizeQuery("Oraclize query was sent, standing by for the answer..");
    }

    function __callback(bytes32 myid, string result, bytes proof) {
        if (msg.sender != oraclize_cbAddress()) throw;
        uint ETHUSD = parseInt(result, 2); // in $ cents
        lastResult = ETHUSD
        newPriceTicker(name,ETHUSD,now);
    }
}