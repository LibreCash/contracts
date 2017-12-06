pragma solidity ^0.4.10;
import "../zeppelin/math/SafeMath.sol";
library Helpers {
	using SafeMath for uint256;
	function parseIntRound(string _a, uint256 _b) internal pure returns (uint256) {
		bytes memory bresult = bytes(_a);
		uint256 mint = 0;
		_b++;
		bool decimals = false;
		for (uint i = 0; i < bresult.length; i++) {
			if ((bresult[i] >= 48) && (bresult[i] <= 57)) {
				if (decimals) {
					if (_b == 0) {
						break;
					}
					else
						_b--;
				}
				if (_b == 0) {
					if (uint(bresult[i]) - 48 >= 5)
						mint += 1;
				} else {
					mint *= 10;
					mint += uint(bresult[i]) - 48;
				}
			} else if (bresult[i] == 46)
				decimals = true;
		}
		if (_b > 0)
			mint *= 10**(_b - 1);
		return mint;
	}

	 /**
     * @dev Calculate percents using fixed-float arithmetic.
     * @param _numerator - Calculation numerator (first number)
     * @param _denominator - Calculation denomirator (first number)
     * @param _precision - calc precision
     */
    function percent(uint _numerator, uint _denominator, uint _precision) internal constant returns(uint) {
        uint numerator = _numerator.mul(10 ** (_precision + 1));
        uint quotient = numerator.div(_denominator).add(5).div(10);
        return quotient;
    }


}