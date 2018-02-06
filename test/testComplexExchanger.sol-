import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/ComplexExchanger.sol";


contract TestComplexExchanger {
    function testGetState() {
        ComplexExchanger ex = ComplexExchanger(DeployedAddresses.ComplexExchanger());

        uint expected = 4;
        uint state = uint(ex.getState());

        Assert.equal(state, expected, "State should be 4 (REQUEST_RATES)");
    }
}