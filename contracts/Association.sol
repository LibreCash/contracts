pragma solidity ^0.4.18;

import "./zeppelin/ownership/Ownable.sol";
import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/Math.sol";
import "./token/LibreCash.sol";
import "./ComplexBank.sol";

/**
 * The shareholder association contract itself
 */
contract Association is Ownable {
    using SafeMath for uint256;

    uint public minimumQuorum;
    uint public minDebatingPeriod;
    uint256 public numProposals;
    Proposal[] proposals;

    ERC20 public sharesTokenAddress;
    ComplexBank public bank;
    LibreCash public cash;

    uint constant MINIMAL_VOTE_BALANCE = 0;

    event ProposalAdded(uint proposalID, address recipient, uint amount, uint buffer, string description, uint deadLine);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, int result, uint quorum);
    event ProposalBlocking(uint proposalID, address recipient, uint amount, string description);
    event ChangeOfRules(uint newMinimumQuorum, uint newdebatingPeriod, address newSharesTokenAddress);

    enum TypeProposal {
        UNIVERSAL,
        TRANSFER_OWNERSHIP,
        ATTACH_TOKEN,
        SET_BANK_ADDRESS,
        SET_FEES,
        ADD_ORACLE,
        DISABLE_ORACLE,
        ENABLE_ORACLE,
        DELETE_ORACLE,
        SET_SCHEDULER,
        WITHDRAW_BALANCE,
        SET_ORACLE_TIMEOUT,
        SET_ORACLE_ACTUAL,
        SET_RATE_PERIOD,
        SET_PAUSED,
        CLAIM_OWNERSHIP,
        CHANGE_ARBITRATOR
    }

    enum Status {
        ACTIVE,
        FINISHED,
        BLOCKED
    }

    struct Proposal {
        TypeProposal tp;
        address recipient;
        uint amount;
        uint buffer;
        string description;
        uint votingDeadline;
        bytes transactionBytecode;
        uint numberOfVotes;
        Vote[] votes;
        mapping (address => bool) voted;
        Status status;
    }

    struct Vote {
        bool inSupport;
        address voter;
    }

    // Modifier that allows only shareholders to vote and create new proposals
    modifier onlyShareholders {
        require(sharesTokenAddress.balanceOf(msg.sender) > MINIMAL_VOTE_BALANCE);
        _;
    }

    /**
     * Constructor function
     *
     * First time setup
     */
    function Association(ERC20 sharesAddress, ComplexBank _bank, LibreCash _cash, uint minShares, uint minDebatePeriod) public {
        changeVotingRules(sharesAddress, _bank, _cash, minShares, minDebatePeriod);
    }

    function getTokenBalance() public view returns(uint256) {
        return sharesTokenAddress.balanceOf(msg.sender);
    }

    function prsLength() public view returns (uint) {
        return proposals.length;
    }
    // Change to internal after testing
    function calcVotes(uint256 proposalID) public view returns(uint256, uint256) {
        Vote[] memory votes = proposals[proposalID].votes;

        uint yea = 0;
        uint nay = 0;
        for (uint i = 0; i < votes.length; ++i) {
            Vote memory v = votes[i];
            uint voteWeight = sharesTokenAddress.balanceOf(v.voter);
            if (v.inSupport) {
                yea += voteWeight;
            } else {
                nay += voteWeight;
            }
        }
        return(yea, nay);
    }

    function getVotingData(uint256 proposalID) public view returns (
        uint256,
        uint256,
        bool,
        uint256
    ) {
        Proposal storage p = proposals[proposalID];
        uint256 yea;
        uint256 nay;
        (yea, nay) = calcVotes(proposalID);
        return (yea, nay, p.voted[msg.sender], p.votingDeadline);
    }

    function getProposal(uint256 proposalID) public view returns (TypeProposal, address, uint, uint, bytes, string, Status) {
        return (
            proposals[proposalID].tp,
            proposals[proposalID].recipient,
            proposals[proposalID].amount,
            proposals[proposalID].buffer,
            proposals[proposalID].transactionBytecode,
            proposals[proposalID].description,
            proposals[proposalID].status
        );
    }

    function blockingProposal(uint proposalID) public onlyOwner {
        require(proposals[proposalID].status == Status.ACTIVE);

        proposals[proposalID].status = Status.BLOCKED;
        numProposals = numProposals.sub(1);
        ProposalBlocking(proposalID, proposals[proposalID].recipient, proposals[proposalID].amount, proposals[proposalID].description);
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need to be discussed for at least `minSecondsForDebate` seconds
     * and all voters combined must own more than `minimumSharesToPassAVote` shares of token `sharesAddress` to be executed
     *
     * @param sharesAddress token address
     * @param minimumSharesToPassAVote proposal can vote only if the sum of shares held by all voters exceed this number
     * @param minSecondsForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     */
    function changeVotingRules(ERC20 sharesAddress, ComplexBank _bank, LibreCash _cash, uint minimumSharesToPassAVote, uint minSecondsForDebate) public onlyOwner {
        sharesTokenAddress = ERC20(sharesAddress);
        bank = ComplexBank(_bank);
        cash = LibreCash(_cash);
        if (minimumSharesToPassAVote == 0) 
            minimumSharesToPassAVote = 1;
        minimumQuorum = minimumSharesToPassAVote;
        minDebatingPeriod = minSecondsForDebate;
        ChangeOfRules(minimumQuorum, minDebatingPeriod, sharesTokenAddress);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `beneficiary` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param beneficiary who to send the ether to
     * @param weiAmount amount of ether to send, in wei
     * @param jobDescription Description of job
     * @param transactionBytecode bytecode of transaction
     */
    function newProposal(
        TypeProposal tp,
        address beneficiary,
        uint weiAmount,
        uint _buffer,
        string jobDescription,
        uint debatingPeriod,
        bytes transactionBytecode
    )
        public
        onlyShareholders
        returns (uint proposalID)
    {
        proposalID = proposals.length++; 
        Proposal storage p = proposals[proposalID];
        p.tp = tp;
        p.recipient = beneficiary;
        p.amount = weiAmount;
        p.buffer = _buffer;
        p.transactionBytecode = transactionBytecode;
        p.description = jobDescription;
        p.status = Status.ACTIVE;
        p.votingDeadline = now + ((debatingPeriod >= minDebatingPeriod) ? debatingPeriod : minDebatingPeriod);
        p.numberOfVotes = 0;
        numProposals = numProposals.add(1);
        ProposalAdded(proposalID, beneficiary, weiAmount, _buffer, jobDescription, p.votingDeadline);

        return proposalID;
    }
    
    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalID`
     *
     * @param proposalID number of proposal
     * @param supportsProposal either in favor or against it
     */
    function vote(
        uint proposalID,
        bool supportsProposal
    )
        public
        onlyShareholders
        returns (uint voteID)
    {
        Proposal storage p = proposals[proposalID];
        
        require(
            p.status == Status.ACTIVE && 
            !p.voted[msg.sender] && 
            p.votingDeadline > now
        );

        voteID = p.votes.length++;
        p.votes[voteID] = Vote({
            inSupport: supportsProposal, 
            voter: msg.sender
        });

        p.voted[msg.sender] = true;

        p.numberOfVotes = voteID + 1;
        Voted(proposalID, supportsProposal, msg.sender);
        return voteID;
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalID` and execute it if approved
     *
     * @param proposalID proposal number    
     */
    function executeProposal(uint proposalID) public {
        Proposal storage p = proposals[proposalID];

        require(
            p.status == Status.ACTIVE && 
            now > p.votingDeadline
        );


        // ...then tally the results
        uint quorum;
        uint yea;
        uint nay;
        
        (yea, nay) = calcVotes(proposalID);
        quorum = yea + nay;


        require(quorum >= minimumQuorum); // Check if a minimum quorum has been reached

        if (yea > nay) {
            if (p.tp == TypeProposal.UNIVERSAL)
                require(p.recipient.call.value(p.amount)(p.transactionBytecode));
            else if (p.tp == TypeProposal.TRANSFER_OWNERSHIP) {
                bank.transferOwnership(p.recipient);
            } else if (p.tp == TypeProposal.ATTACH_TOKEN) {
                bank.attachToken(p.recipient);
            } else if (p.tp == TypeProposal.SET_FEES) {
                bank.setFees(p.amount, p.buffer);
            } else if (p.tp == TypeProposal.ADD_ORACLE) {
                bank.addOracle(p.recipient);
            } else if (p.tp == TypeProposal.DISABLE_ORACLE) {
                bank.disableOracle(p.recipient);
            } else if (p.tp == TypeProposal.ENABLE_ORACLE) {
                bank.enableOracle(p.recipient);
            } else if (p.tp == TypeProposal.DELETE_ORACLE) {
                bank.deleteOracle(p.recipient);
            } else if (p.tp == TypeProposal.SET_SCHEDULER) {
                bank.setScheduler(p.recipient);
            } else if (p.tp == TypeProposal.WITHDRAW_BALANCE) {
                bank.withdrawBalance();
            } else if (p.tp == TypeProposal.SET_ORACLE_TIMEOUT) {
                bank.setOracleTimeout(p.amount);
            } else if (p.tp == TypeProposal.SET_ORACLE_ACTUAL) {
                bank.setOracleActual(p.amount);
            } else if (p.tp == TypeProposal.SET_RATE_PERIOD) {
                bank.setRatePeriod(p.amount);
            } else if (p.tp == TypeProposal.SET_PAUSED) {
                (p.amount > 0) ? bank.pause() : bank.unpause();
            } else if (p.tp == TypeProposal.CLAIM_OWNERSHIP) {
                bank.claimOwnership();
            } else if (p.tp == TypeProposal.SET_BANK_ADDRESS) {
                bank.transferTokenOwner(p.recipient);
                setBankAddress(p.recipient);
                bank.claimOwnership();
            } else if (p.tp == TypeProposal.CHANGE_ARBITRATOR) {
                transferOwnership(p.recipient);
            }
        }

        proposals[proposalID].status = Status.FINISHED;
        numProposals = numProposals.sub(1);
        // Fire Events
        ProposalTallied(proposalID, int(yea - nay), quorum);
    }

    function prUniversal(address beneficiary, uint weiAmount, 
                                string jobDescription, uint debatingPeriod, bytes transactionBytecode) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(beneficiary != address(0x0));
        return newProposal(TypeProposal.UNIVERSAL, beneficiary, weiAmount, 0, 
                            jobDescription, debatingPeriod, transactionBytecode);
    }

    function prUniversalInEther(address beneficiary, uint etherAmount, 
                                string jobDescription, uint debatingPeriod, bytes transactionBytecode) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(beneficiary != address(0x0));
        return newProposal(TypeProposal.UNIVERSAL, beneficiary, etherAmount * 1 ether, 0, 
                            jobDescription, debatingPeriod, transactionBytecode);
    }

    function prTransferOwnership(address newOwner, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.TRANSFER_OWNERSHIP, newOwner, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prAttachToken(address _tokenAddress, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_tokenAddress != address(0x0));
        return newProposal(TypeProposal.ATTACH_TOKEN, _tokenAddress, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prFees(uint256 _buyFee, uint256 _sellFee, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.SET_FEES, address(0), _buyFee, _sellFee, 
                            jobDescription, debatingPeriod, "0");
    }

    function prAddOracle(address _address, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_address != address(0x0));
        return newProposal(TypeProposal.ADD_ORACLE, _address, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prDisableOracle(address _address, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_address != address(0x0));
        return newProposal(TypeProposal.DISABLE_ORACLE, _address, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prEnableOracle(address _address, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_address != address(0x0));
        return newProposal(TypeProposal.ENABLE_ORACLE, _address, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prDeleteOracle(address _address, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_address != address(0x0));
        return newProposal(TypeProposal.DELETE_ORACLE, _address, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prScheduler(address _scheduler, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_scheduler != address(0x0));
        return newProposal(TypeProposal.SET_SCHEDULER, _scheduler, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prWithdrawBalance(string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.WITHDRAW_BALANCE, address(0), 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prBankAddress(address _bankAddress, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        require(_bankAddress != address(0x0));
        return newProposal(TypeProposal.SET_BANK_ADDRESS, _bankAddress, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prOracleTimeout(uint256 _period, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.SET_ORACLE_TIMEOUT, address(0), _period, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prOracleActual(uint256 _period, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.SET_ORACLE_ACTUAL, address(0), _period, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prRatePeriod(uint256 _period, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.SET_RATE_PERIOD, address(0), _period, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prPause(uint256 paused, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.SET_PAUSED, address(0), paused, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function prClaimOwnership(string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.CLAIM_OWNERSHIP, address(this), 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }
    
    function prChangeArbitrator(address newArbitrator, string jobDescription, uint debatingPeriod) 
        public onlyShareholders returns (uint proposalID) 
    {
        return newProposal(TypeProposal.CHANGE_ARBITRATOR, newArbitrator, 0, 0, 
                            jobDescription, debatingPeriod, "0");
    }

    function setBankAddress(address _bank) internal {
        bank = ComplexBank(_bank);
    }

    function() public payable {}
}

