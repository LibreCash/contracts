pragma solidity ^0.4.18;

import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/Math.sol";
import "./token/LibreCash.sol";
import "./ComplexBank.sol";

/**
 * The shareholder association contract itself
 */
contract Association  {

    modifier onlyArbitrator() {
        require(msg.sender == owner);
        _;
    }

    address owner;
    using SafeMath for uint256;

    uint public minimumQuorum;
    uint public minDebatingPeriod;
    uint256 public numProposals;
    Proposal[] proposals;

    ERC20 public sharesTokenAddress;
    ComplexBank public bank;
    LibreCash public cash;

    uint constant MINIMAL_VOTE_BALANCE = 2000 * 10 ** 18;

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
        bytes bytecode;
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
        require(sharesTokenAddress.balanceOf(msg.sender) >= MINIMAL_VOTE_BALANCE);
        _;
    }

    /**
     * Constructor function
     *
     * First time setup
     */
    function Association(ERC20 sharesAddress, ComplexBank _bank, LibreCash _cash, uint minShares, uint minDebatePeriod) public {
        owner = msg.sender;
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
            proposals[proposalID].bytecode,
            proposals[proposalID].description,
            proposals[proposalID].status
        );
    }

    function blockingProposal(uint proposalID) public onlyArbitrator {
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
    function changeVotingRules(ERC20 sharesAddress, ComplexBank _bank, LibreCash _cash, uint minimumSharesToPassAVote, uint minSecondsForDebate) public onlyArbitrator {
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
     * @param _beneficiary who to send the ether to
     * @param _weiAmount amount of ether to send, in wei
     * @param _jobDescription Description of job
     * @param _transactionBytecode bytecode of transaction
     */
    function newProposal(
        TypeProposal tp,
        address _beneficiary,
        uint _weiAmount,
        uint _buffer,
        string _jobDescription,
        uint _debatingPeriod,
        bytes _transactionBytecode
    )
        public
        onlyShareholders
        returns (uint proposalID)
    {
        if (tp == TypeProposal.UNIVERSAL ||
            tp == TypeProposal.TRANSFER_OWNERSHIP ||
            tp == TypeProposal.ATTACH_TOKEN ||
            tp == TypeProposal.ADD_ORACLE ||
            tp == TypeProposal.DISABLE_ORACLE ||
            tp == TypeProposal.ENABLE_ORACLE ||
            tp == TypeProposal.DELETE_ORACLE ||
            tp == TypeProposal.SET_SCHEDULER ||
            tp == TypeProposal.SET_BANK_ADDRESS ||
            tp == TypeProposal.CHANGE_ARBITRATOR)
          require (_beneficiary != address(0));

        proposalID = proposals.length++; 
        Proposal storage p = proposals[proposalID];
        p.tp = tp;
        p.recipient = _beneficiary;
        p.amount = _weiAmount;
        p.buffer = _buffer;
        p.bytecode = _transactionBytecode;
        p.description = _jobDescription;
        p.status = Status.ACTIVE;
        p.votingDeadline = now + ((_debatingPeriod >= minDebatingPeriod) ? _debatingPeriod : minDebatingPeriod);
        p.numberOfVotes = 0;
        numProposals = numProposals.add(1);
        ProposalAdded(proposalID, _beneficiary, _weiAmount, _buffer, _jobDescription, p.votingDeadline);

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
                require(p.recipient.call.value(p.amount)(p.bytecode));
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
                changeArbitrator(p.recipient);
            }
        }

        proposals[proposalID].status = Status.FINISHED;
        numProposals = numProposals.sub(1);
        // Fire Events
        ProposalTallied(proposalID, int(yea - nay), quorum);
    }

    function setBankAddress(address _bank) internal {
        bank = ComplexBank(_bank);
    }

    function changeArbitrator(address newArbitrator) internal {
        require(msg.sender == address(this));
        owner = newArbitrator;
    }

    function() public payable {}
}

