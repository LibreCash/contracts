pragma solidity ^0.4.21;

import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/math/SafeMath.sol";


contract ProposalSystem {
    enum Status {
        ACTIVE,
        FINISHED,
        BLOCKED
    }

    struct Proposal {
        address initiator;
        address target;
        string description;
        uint256 value;
        uint deadline;
        bytes bytecode;
        Status status;
        uint256 yea;
        uint256 nay;
        mapping (address => bool) voted;
    }

    uint256 public numProposals;
    Proposal[] public proposals;
}


contract VotingSystem is ProposalSystem {
    using SafeMath for uint256;

    event Lock(address locker, uint256 value);
    event Unlock(address locker, uint256 value);

    mapping (address => uint256) public locked;
    ERC20 public sharesTokenAddress;
    uint256 constant VOTE_LIMIT = 10;
    uint256 constant MINIMAL_VOTE_BALANCE = 2000 * 10 ** 18;

    modifier voters {
        require(locked[msg.sender] >= MINIMAL_VOTE_BALANCE);
        _;
    }

    //event LockPhase(string descr);

    function lock(uint256 _amount) public {
        sharesTokenAddress.transferFrom(msg.sender, address(this), _amount);
        for (uint i = 0; i < voted[msg.sender].length; i++) {
            if (proposals[voted[msg.sender][i].proposal].status == Status.ACTIVE) {
                if (voted[msg.sender][i].support) {
                    proposals[voted[msg.sender][i].proposal].yea = proposals[voted[msg.sender][i].proposal].yea.add(_amount);
                } else {
                    proposals[voted[msg.sender][i].proposal].nay = proposals[voted[msg.sender][i].proposal].nay.add(_amount);
                }
            }
        }
        locked[msg.sender] = locked[msg.sender].add(_amount);
        emit Lock(msg.sender, _amount);
    }

    function votes() public view returns (uint256) {
        return locked[msg.sender];
    }

    function unlock(uint256 _amount) public {
        sharesTokenAddress.transfer(msg.sender, _amount);
        for (uint i = 0; i < voted[msg.sender].length; i++) {
            if (proposals[voted[msg.sender][i].proposal].status == Status.ACTIVE) {
                if (voted[msg.sender][i].support) {
                    proposals[voted[msg.sender][i].proposal].yea = proposals[voted[msg.sender][i].proposal].yea.sub(_amount);
                } else {
                    proposals[voted[msg.sender][i].proposal].nay = proposals[voted[msg.sender][i].proposal].nay.sub(_amount);
                }
            }
        }
        locked[msg.sender] = locked[msg.sender].sub(_amount);
        emit Unlock(msg.sender, _amount);
    }

    struct votePosition {
        uint256 proposal;
        bool support;
    }

    mapping (address => votePosition[]) public voted;

    function addVote(uint256 proposal, bool support) internal {
        uint256 len = voted[msg.sender].length;
        bool added = false;
        for (uint i = 0; i < len; i++) {
            if (proposals[voted[msg.sender][i].proposal].status != Status.ACTIVE) {
                voted[msg.sender][i] = votePosition({ proposal: proposal, support: support });
                added = true;
                break;
            }
        }
        if (!added) {
            if (len >= VOTE_LIMIT) revert(); // already voted for vote limit, wait for some proposals to become inactive
            voted[msg.sender].push(votePosition({ proposal: proposal, support: support }));
        }
    }
}


/**
 * The shareholder association contract itself
 */
contract Association is VotingSystem {

    modifier onlyArbitrator() {
        require(msg.sender == owner);
        _;
    }

    address public owner;

    uint public minimumQuorum;
    uint public minDebatingPeriod;

    event ProposalAdded(uint proposalID, address target, string description, uint deadLine, uint value);
    event Voted(uint proposalID, bool position, address voter);
    event ProposalTallied(uint proposalID, int result, uint quorum);
    event ProposalBlocked(uint proposalID, address target, string description);
    event ChangeOfRules(uint newMinimumQuorum, uint newdebatingPeriod, address newSharesTokenAddress);

    struct Vote {
        bool inSupport;
        address voter;
    }

    /**
     * Constructor function
     *
     * First time setup
     */
    function Association(ERC20 sharesAddress, uint minShares, uint minDebatePeriod) public {
        owner = msg.sender;
        changeVotingRules(sharesAddress, minShares, minDebatePeriod);
    }

    /**
     * Get a balance of tokens
     */
    function getTokenBalance() public view returns(uint256) {
        return sharesTokenAddress.balanceOf(msg.sender);
    }

    /**
     * Get a length of proposals
     */
    function prsLength() public view returns (uint) {
        return proposals.length;
    }

    /**
     * Get data about proposal
     * @param proposalID is id proposal
     */
    function getVotingData(uint256 proposalID) public view returns (
        uint256,
        uint256,
        bool,
        uint256
    ) {
        Proposal storage p = proposals[proposalID];
        return (p.yea, p.nay, p.voted[msg.sender], p.deadline);
    }

    /**
     * Get proposal fields
     * @param proposalID is id proposal
     */
    function getProposal(uint256 proposalID) public view returns (address, address, bytes, string, Status, uint256, uint256) {
        return (
            proposals[proposalID].initiator,
            proposals[proposalID].target,
            proposals[proposalID].bytecode,
            proposals[proposalID].description,
            proposals[proposalID].status,
            proposals[proposalID].yea,
            proposals[proposalID].nay
        );
    }

    /**
     * Blocking proposal
     * @param proposalID Proposal ID
     */
    function blockProposal(uint proposalID) public onlyArbitrator {
        require(proposals[proposalID].status == Status.ACTIVE);

        proposals[proposalID].status = Status.BLOCKED;
        numProposals = numProposals.sub(1);
        proposals[proposalID].initiator.transfer(proposals[proposalID].value);
        emit ProposalBlocked(proposalID, proposals[proposalID].target, proposals[proposalID].description);
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
     /* solium-disable-next-line */
    function changeVotingRules(
        ERC20 sharesAddress, 
        uint minimumSharesToPassAVote, 
        uint minSecondsForDebate
    ) public onlyArbitrator {
        sharesTokenAddress = ERC20(sharesAddress);
        if (minimumSharesToPassAVote == 0) 
            minimumSharesToPassAVote = 1;
        minimumQuorum = minimumSharesToPassAVote;
        minDebatingPeriod = minSecondsForDebate;
        emit ChangeOfRules(minimumQuorum, minDebatingPeriod, sharesTokenAddress);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `target` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param _target who to send the ether to
     * @param _jobDescription Description of job
     * @param _transactionBytecode bytecode of transaction
     */
    function newProposal(
        address _target,
        string _jobDescription,
        uint _debatingPeriod,
        bytes _transactionBytecode
    )
        public
        voters
        payable
        returns (uint proposalID)
    {
        require(_target != address(0));

        proposalID = proposals.length++; 
        Proposal storage p = proposals[proposalID];
        p.initiator = msg.sender;
        p.value = msg.value;
        p.target = _target;
        p.bytecode = _transactionBytecode;
        p.description = _jobDescription;
        p.status = Status.ACTIVE;
        p.deadline = now + ((_debatingPeriod >= minDebatingPeriod) ? _debatingPeriod : minDebatingPeriod);
        p.yea = 0;
        p.nay = 0;
        numProposals = numProposals.add(1);
        emit ProposalAdded(proposalID, _target, _jobDescription, p.deadline, p.value);
    }
    
    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`proposalID`
     *
     * @param proposalID number of proposal
     * @param support either in favor or against it
     */
    function vote(
        uint proposalID,
        bool support
    )
        public
        voters
        returns (uint voteID)
    {
        Proposal storage p = proposals[proposalID];
        
        require(
            p.status == Status.ACTIVE && 
            !p.voted[msg.sender] && 
            p.deadline > now
        );

        if (support) {
            p.yea = p.yea.add(locked[msg.sender]);
        } else {
            p.nay = p.nay.add(locked[msg.sender]);
        }

        p.voted[msg.sender] = true;
        addVote(proposalID, support);
        emit Voted(proposalID, support, msg.sender);
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
            now > p.deadline
        );

        uint quorum = p.yea + p.nay;


        require(quorum >= minimumQuorum); // Check if a minimum quorum has been reached

        if (p.yea > p.nay) {
            require(p.target.call.value(p.value)(p.bytecode)); /* solium-disable-line */
        }

        proposals[proposalID].status = Status.FINISHED;
        numProposals = numProposals.sub(1);
        // Fire Events
        emit ProposalTallied(proposalID, int(p.yea - p.nay), quorum);
    }

    /**
     * Change arbitrator
     * @param newArbitrator new arbitrator address
     */
    function changeArbitrator(address newArbitrator) public {
        require(msg.sender == address(this));
        owner = newArbitrator;
    }

    function() public payable {}
}

