pragma solidity ^0.4.23;

import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/math/SafeMath.sol";


contract TokenStore {
    using SafeMath for uint256;
    address owner;
    mapping (address => uint256) balances;
    uint256 totalSupply_;

    event Burn(address indexed burner, uint256 value);
    event Mint(address indexed to, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 value);

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() public {
        owner = msg.sender;
    }

    function balanceOf(address beneficiary) public view returns(uint256) {
        return balances[beneficiary];
    }

    function balanceOf() public view returns(uint256) {
        return balanceOf(msg.sender);
    }

    /**
    * @dev total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
    * @dev Function to mint tokens
    * @param _to The address that will receive the minted tokens.
    * @param _amount The amount of tokens to mint.
    * @return A boolean that indicates if the operation was successful.
    */
    function mint(address _to, uint256 _amount) onlyOwner public returns (bool) {
        totalSupply_ = totalSupply_.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(_to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function burn(uint256 _value) onlyOwner public  {
        require(_value <= balances[msg.sender]);
        // no need to require value <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure
        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit Burn(burner, _value);
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}


contract ProposalSystem {
    event ProposalAdded(uint proposalID, address target, uint deadLine, uint value);
    event ProposalTallied(uint proposalID, int result, uint quorum);
    event ProposalBlocked(uint proposalID, address target);
    event ProposalCancelled(uint proposalID, string description);

    enum Status {
        ACTIVE,
        FINISHED,
        BLOCKED,
        CANCELLED
    }

    struct Proposal {
        address initiator;
        address target;
        string description;
        uint256 etherValue;
        uint deadline;
        bytes bytecode;
        Status status;
        uint256 yea;
        uint256 nay;
        mapping (address => bool) voted;
    }

    uint256 public proposalCount;
    Proposal[] public proposals;
}


contract VotingSystem is ProposalSystem {
    using SafeMath for uint256;

    struct VotePosition {
        uint256 proposal;
        bool support;
    }

    modifier voters {
        require(voteForce[msg.sender] >= minVotes);
        _;
    }

    modifier self {
        require(msg.sender == address(this));
        _;
    }

    modifier active {
        require(
            deadline == 0 ||
            deadline >= now
        );
        _;
    }

    mapping (address => uint256) internal voteForce;
    mapping (address => VotePosition[]) public voted;

    ERC20 public govToken;

    uint256 deadline = 0;
    uint256 constant VOTE_LIMIT = 10;
    uint256 activeVotesLimit = 10;
    uint256 constant MINIMAL_VOTE_BALANCE = 2000 * 10 ** 18;
    uint256 public minVotes = MINIMAL_VOTE_BALANCE;

    /* Implement later - check that proposal p has status p
    function _is(Proposal p, Status s) public returns (bool) {
        return p.status == s;
    }*/

    function lock(uint256 _amount) public {
        voteForce[msg.sender] = voteForce[msg.sender].add(_amount);
        govToken.transferFrom(msg.sender, address(this), _amount);
        changeProposals(_amount, true);
    }

    function unlock(uint256 _amount) public {
        voteForce[msg.sender] = voteForce[msg.sender].sub(_amount);
        changeProposals(_amount, false);
        govToken.transfer(msg.sender, _amount);
    }

    function locked() public view returns (uint256) {
        return voteForce[msg.sender];
    }

    function changeProposals(uint256 _amount, bool isLock) internal {
        for (uint i = 0; i < voted[msg.sender].length; i++) {
            uint256 current = voted[msg.sender][i].proposal;
            if (proposals[current].status == Status.ACTIVE) {
                if (voted[msg.sender][i].support) {
                    proposals[current].yea = isLock ?
                        proposals[current].yea.add(_amount) :
                        proposals[current].yea.sub(_amount);
                } else {
                    proposals[current].nay = isLock ?
                        proposals[current].nay.add(_amount) :
                        proposals[current].nay.sub(_amount);
                }
            }
        }
    }

    function addVote(uint256 proposal, bool support) public active {
        addVote(proposal, support, -1);
    }

    function addVote(uint256 proposal, bool support, int256 _field) internal active {
        int256 field = _field == -1 ? getFreeField() : _field;
        uint current = voted[msg.sender][uint(field)].proposal;

        require(
            field > -1 || // need clean
            // users sets incorrect field
            proposals[current].status != Status.ACTIVE
        );

        voted[msg.sender][uint(field)] = VotePosition({
            proposal: proposal,
            support: support
        });
    }

    function getFreeField() public view returns(int256) {
        uint256 len = voted[msg.sender].length;
        if (len < activeVotesLimit) return int(len);
        for (uint i = 0; i < len; i++) {
            uint current = voted[msg.sender][i].proposal;
            if (proposals[current].status != Status.ACTIVE)
                return int(i);
        }
        return -1;
    }
}


/**
 * The shareholder association contract itself
 */
contract Association is VotingSystem {
    uint256 constant MIN_DEALINE_PAUSE = 14 days;
    struct Vote {
        bool inSupport;
        address voter;
    }

    event Voted(uint proposalID, bool position, address voter);
    event ChangeOfRules(uint minQuorum, uint debatingPeriod, address newGovToken);
    event NewArbitrator(address arbitrator);

    modifier onlyArbitrator() {
        require(msg.sender == owner);
        _;
    }

    address public owner;
    uint public minQuorum;
    uint public minPeriod;

    /**
     * Constructor function
     *
     * First time setup
     */
    constructor(
        ERC20 gov,
        uint minShares,
        uint minDebate
    ) public {
        owner = msg.sender;
        changeVotingRules(gov, minShares, minDebate);
    }

    /**
     * Get a balance of tokens
     */
    function unholdedBalance() public view returns(uint256) {
        return govToken.balanceOf(msg.sender);
    }

    /**
     * Get a length of proposals
     */
    function proposalsLength() public view returns (uint) {
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
     * Block proposal
     * @param proposalID Proposal ID
     */
    function blockProposal(uint proposalID) public onlyArbitrator {
        Proposal memory proposal = proposals[proposalID];
        require(proposal.status == Status.ACTIVE);

        proposals[proposalID].status = Status.BLOCKED;
        proposalCount = proposalCount.sub(1);
        proposal.initiator.transfer(proposal.etherValue);
        emit ProposalBlocked(proposalID, proposal.target);
    }

    /**
     * Cancel proposal
     * @param proposalID Proposal ID
     */
    function cancelProposal(uint proposalID) public voters {
        require(proposals[proposalID].status == Status.ACTIVE &&
                proposals[proposalID].yea <= proposals[proposalID].nay &&
                proposals[proposalID].deadline > now);

        proposals[proposalID].status = Status.CANCELLED;
        proposalCount = proposalCount.sub(1);
        proposals[proposalID].initiator.transfer(proposals[proposalID].etherValue);
        emit ProposalCancelled(proposalID, proposals[proposalID].description);
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need to be discussed for at least `minSecondsForDebate` seconds
     * and all voters combined must own more than `minShares` shares of token `gov` to be executed
     *
     * @param gov token address
     * @param minShares proposal can vote only if the sum of shares held by all voters exceed this number
     * @param minSecondsForDebate the minimum amount of delay between when a proposal is made and when it can be executed
     */
     /* solium-disable-next-line */
    function changeVotingRules(
        ERC20 gov,
        uint minShares,
        uint minDebate
    ) public onlyArbitrator {
        require(
            minShares >= 0 &&
            minPeriod > 0
        );
        govToken = ERC20(gov);
        minQuorum = minShares;
        minPeriod = minSecondsForDebate;
        emit ChangeOfRules(minQuorum, minPeriod, govToken);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `target` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param _target who to send the ether to
     * @param _jobDescription Description of job
     * @param _bytecode bytecode of transaction
     */
    function newProposal(
        address _target,
        string _jobDescription,
        uint period,
        bytes _bytecode
    )
        public
        active
        voters
        payable
        returns (uint proposalID)
    {
        require(_target != address(0));

        proposalID = proposals.length++;
        Proposal storage p = proposals[proposalID];
        p.initiator = msg.sender;
        p.etherValue = msg.value;
        p.target = _target;
        p.bytecode = _bytecode;
        p.description = _jobDescription;
        p.status = Status.ACTIVE;
        p.deadline = getDeadline(period);
        p.yea = 0;
        p.nay = 0;
        proposalCount = proposalCount.add(1);
        emit ProposalAdded(proposalID, _target, p.deadline, p.etherValue);
    }

    function getDeadline(uint256 period) internal view returns (uint256) {
        return now.add((period >= minPeriod) ? period : minPeriod);
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
        active
        voters
    {
        Proposal storage p = proposals[proposalID];

        require(
            p.status == Status.ACTIVE &&
            !p.voted[msg.sender] &&
            p.deadline > now
        );

        if (support) {
            p.yea = p.yea.add(voteForce[msg.sender]);
        } else {
            p.nay = p.nay.add(voteForce[msg.sender]);
        }

        p.voted[msg.sender] = true;
        addVote(proposalID, support);
        emit Voted(proposalID, support, msg.sender);
    }

    /**
     * Finish vote
     *
     * Count the votes proposal #`proposalID` and execute it if approved
     *
     * @param proposalID proposal number
     */
    function executeProposal(uint proposalID) public active {
        Proposal storage p = proposals[proposalID];

        require(
            p.status == Status.ACTIVE &&
            now > p.deadline
        );

        uint quorum = p.yea + p.nay;


        require(quorum >= minQuorum); // Check if a minimum quorum has been reached

        if (p.yea > p.nay) {
            require(p.target.call.value(p.etherValue)(p.bytecode)); /* solium-disable-line */
        } else {
            revert();
        }

        proposals[proposalID].status = Status.FINISHED;
        proposalCount = proposalCount.sub(1);
        // Fire Events
        emit ProposalTallied(proposalID, int(p.yea - p.nay), quorum);
    }

    /**
     * Change arbitrator
     * @param arbitrator - new arbitrator address
     */
    function changeArbitrator(address arbitrator) public self {
        require(arbitrator != address(0));
        owner = arbitrator;
        emit NewArbitrator(arbitrator);
    }

    function setActiveLimit(uint256 voteLimit) public self {
        require(voteLimit > VOTE_LIMIT);
        activeVotesLimit = voteLimit;
    }

    function setMinVotes(uint256 _minVotes) public self {
        require(
            _minVotes <= MINIMAL_VOTE_BALANCE &&
            _minVotes > 0
        );
        minVotes = _minVotes;
    }

    function setPause(uint256 date) public self {
        require(
            date >= (now + MIN_DEALINE_PAUSE) ||
            date == 0
        );
        deadline = date;
    }
}
