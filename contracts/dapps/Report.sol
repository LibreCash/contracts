
pragma solidity ^0.4.18;

import "../zeppelin/ownership/Claimable.sol";

contract ReportStorage is Claimable {
    Report[] public reports;

    struct Report {
        string textReport;
        uint date;
    }

    function counter() public view returns(uint256) {
      return reports.length;
    }
         
    function addNewReport(string newReport) public onlyOwner {
        reports.push(Report(newReport, now));
    }
}