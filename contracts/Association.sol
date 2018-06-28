pragma solidity ^0.4.23;

import "./zeppelin/token/ERC20.sol";
import "./zeppelin/math/Math.sol";
import "./zeppelin/math/SafeMath.sol";

// Token-like contract to store locked at сontract tokens
contract TokenStore {
    using SafeMath for uint256;
    string public constant name = "LibreVoting";
    string public constant symbol = "LbVote";
    uint32 public constant decimals = 18;
    address public owner;
    mapping (address => uint256) balances;
    uint256 totalSupply_;

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
        return true;
    }

    function burn(address beneficiar, uint256 _value) onlyOwner public  {
        require(_value <= balances[beneficiar]);
        balances[beneficiar] = balances[beneficiar].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }
}


contract ProposalSystem {
    event ProposalAdded(uint256 id);
    event ProposalTallied(uint256 id);
    event ProposalBlocked(uint256 id, address arbitrator);
    event ProposalCancelled(uint256 id, address sender);

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
        uint256 deadline;
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

    mapping (address => VotePosition[]) public voted;

    TokenStore public voteToken;
    ERC20 public govToken;

    uint256 public deadline = 0;
    uint256 constant MIN_VOTE_LIMIT = 10;
    uint256 public activeVotesLimit = 10;
    uint256 constant MINIMAL_VOTE_BALANCE = 2000 * 10 ** 18;
    uint256 public minVotes = MINIMAL_VOTE_BALANCE;

    /* Implement later - check that proposal p has status p
    function _is(Proposal p, Status s) public returns (bool) {
        return p.status == s;
    }*/

    function lock(uint256 _amount) public {
        voteToken.mint(msg.sender, _amount);
        recalcProposal(_amount, true);
        govToken.transferFrom(msg.sender, address(this), _amount);
    }

    function unlock(uint256 _amount) public {
        voteToken.burn(msg.sender, _amount);
        recalcProposal(_amount, false);
        govToken.transfer(msg.sender, _amount);
    }

    function votePower() public view returns (uint256) {
        return voteToken.balanceOf(msg.sender);
    }


    function recalcProposal(uint256 _amount, bool beenLocked) internal {
        for (uint256 i = 0; i < voted[msg.sender].length; i++) {
            uint256 current = voted[msg.sender][i].proposal;
            if (proposals[current].status == Status.ACTIVE && proposals[current].deadline > now) {
                if (voted[msg.sender][i].support) {
                    proposals[current].yea = beenLocked ?
                        proposals[current].yea.add(_amount) :
                        proposals[current].yea.sub(_amount);
                } else {
                    proposals[current].nay = beenLocked ?
                        proposals[current].nay.add(_amount) :
                        proposals[current].nay.sub(_amount);
                }
            }
        }
    }

    function addVote(uint256 proposal, bool support) internal active {
        addVote(proposal, support, -1);
    }

    function addVote(uint256 proposal, bool support, int256 _field) internal active {
        int256 field = _field == -1 ? getFreeField() : _field;
        require(field > -1 && field < int256(activeVotesLimit));
        if (field >= int256(voted[msg.sender].length)) {
            voted[msg.sender].length++;
        } else {
            // user sets incorrect field
            uint256 current = voted[msg.sender][uint256(field)].proposal;
            require(proposals[current].status != Status.ACTIVE);
        }

        voted[msg.sender][uint256(field)] = VotePosition({
            proposal: proposal,
            support: support
        });
    }

    function getFreeField() public view returns(int256) {
        uint256 len = voted[msg.sender].length;
        if (len < activeVotesLimit) return int256(len);
        for (uint256 i = 0; i < len; i++) {
            uint256 current = voted[msg.sender][i].proposal;
            if (
                proposals[current].status != Status.ACTIVE ||
                proposals[current].deadline < now
            )
                return int256(i);
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

    event Voted(uint256 id, bool position, uint256 power);
    event RulesChange(address token, uint256 quorum, uint256 period, uint256 votes);
    event NewArbitrator(address arbitrator);

    modifier onlyArbitrator() {
        require(msg.sender == arbitrator);
        _;
    }

    modifier voters {
        require(canVote());
        _;
    }

    address public arbitrator;
    uint256 public minQuorum;
    uint256 public minPeriod;

    function canVote() public view returns(bool) {
        return voteToken.balanceOf(msg.sender) >= minVotes;
    }

    function canExecute(uint256 id) public view returns (bool) {
        Proposal storage p = proposals[id];
        uint256 quorum = p.yea + p.nay;
        return (
            p.status == Status.ACTIVE &&
            now > p.deadline &&
            quorum >= minQuorum &&
            p.yea > p.nay
        );
    }

    /**
     * Constructor function
     *
     * First time setup
     */
    constructor(
        ERC20 gov,
        uint256 _minQuorum,
        uint256 _minPeriod,
        uint256 _minVotes
    ) public {
        arbitrator = msg.sender;
        voteToken = new TokenStore();
        changeRules(gov, _minQuorum, _minPeriod, _minVotes);
    }

    /**
     * Get a balance of tokens
     */
    function unheldBalance() public view returns(uint256) {
        return govToken.balanceOf(msg.sender);
    }

    /**
     * Get a length of proposals
     */
    function proposalsLength() public view returns (uint256) {
        return proposals.length;
    }

    /**
     * Get data about proposal
     * @param id is id proposal
     */
    function getVotingData(uint256 id) public view returns (
        uint256,
        uint256,
        bool,
        uint256
    ) {
        Proposal storage p = proposals[id];
        return (p.yea, p.nay, p.voted[msg.sender], p.deadline);
    }

    /**
     * Get proposal fields
     * @param id is id proposal
     */
    /*function getProposal(uint256 id) public view returns (
        address,
        //address,
        bytes,
        //string,
        uint256, Status,
        uint256,
        uint256
    ) {
        return (
            proposals[id].initiator,
            //proposals[id].target,
            proposals[id].bytecode,
            //proposals[id].description,
            proposals[id].etherValue,
            proposals[id].status,
            proposals[id].yea,
            proposals[id].nay,
            proposals[id].deadline
        );
    }*/

    /**
     * Veto proposal
     * @param id Proposal ID
     */
    function veto(uint256 id) public onlyArbitrator {
        Proposal memory proposal = proposals[id];
        require(proposal.status == Status.ACTIVE);

        proposals[id].status = Status.BLOCKED;
        proposalCount = proposalCount.sub(1);
        proposal.initiator.transfer(proposal.etherValue);
        emit ProposalBlocked(id, arbitrator);
    }

    /**
     * Cancel proposal
     * @param id Proposal ID
     */
    function cancel(uint256 id) public voters {
        Proposal storage p = proposals[id];
        require(p.status == Status.ACTIVE && p.deadline < now);
        require(p.yea <= p.nay || p.yea + p.nay < minQuorum);

        p.status = Status.CANCELLED;
        proposalCount = proposalCount.sub(1);
        p.initiator.transfer(p.etherValue);
        emit ProposalCancelled(id, msg.sender);
    }

    /**
     * Change voting rules
     *
     * Make so that proposals need to be discussed for at least `minSecondsForDebate` seconds
     * and all voters combined must own more than `minShares` shares of token `gov` to be executed
     *
     * @param gov token address
     * @param _minQuorum proposal can vote only if the sum of shares held by all voters exceed this number
     * @param _minPeriod the minimum amount of delay between when a proposal is made and when it can be executed
     * @param _minVotes the minimum amount of votes to vote
     */
     /* solium-disable-next-line */
    function changeRules(
        ERC20 gov,
        uint256 _minQuorum,
        uint256 _minPeriod,
        uint256 _minVotes
    ) public onlyArbitrator {
        require(
            _minQuorum >= 0 &&
            _minPeriod > 0 &&
            _minVotes <= MINIMAL_VOTE_BALANCE &&
            _minVotes > 0
        );

        govToken = ERC20(gov);
        minQuorum = _minQuorum;
        minPeriod = _minPeriod;
        minVotes = _minVotes;
        emit RulesChange(govToken, minQuorum, minPeriod, minVotes);
    }

    /**
     * Add Proposal
     *
     * Propose to send `weiAmount / 1e18` ether to `target` for `jobDescription`. `transactionBytecode ? Contains : Does not contain` code.
     *
     * @param _target who to send the ether to
     * @param _description job description
     * @param _period period in seconds
     * @param _bytecode bytecode of transaction
     */
    function newProposal(
        address _target,
        string _description,
        uint256 _period,
        bytes _bytecode
    )
        public
        active
        voters
        payable
        returns (uint256 id)
    {
        require(_target != address(0));

        id = proposals.length++;
        Proposal storage p = proposals[id];
        p.initiator = msg.sender;
        p.etherValue = msg.value;
        p.target = _target;
        p.bytecode = _bytecode;
        p.description = _description;
        p.status = Status.ACTIVE;
        p.deadline = getDeadline(_period);
        p.yea = 0;
        p.nay = 0;
        proposalCount = proposalCount.add(1);
        emit ProposalAdded(id);
    }

    function getDeadline(uint256 period) internal view returns (uint256) {
        return now.add((period >= minPeriod) ? period : minPeriod);
    }

    /**
     * Log a vote for a proposal
     *
     * Vote `supportsProposal? in support of : against` proposal #`id`
     *
     * @param id number of proposal
     * @param support either in favor or against it
     */
    function vote(
        uint256 id,
        bool support
    )
        public
        active
        voters
    {
        Proposal storage p = proposals[id];

        require(
            p.status == Status.ACTIVE &&
            !p.voted[msg.sender] &&
            p.deadline > now
        );
        p.voted[msg.sender] = true;

        uint256 power = votePower();

        if (support) {
            p.yea = p.yea.add(power);
        } else {
            p.nay = p.nay.add(power);
        }

        addVote(id, support);
        emit Voted(id, support, power);
    }

    /**
     * Execute proposal and finish vote
     *
     * Count the votes proposal #`id` and execute it if approved
     *
     * @param id proposal number
     */
    function execute(uint256 id) public active {
        require(canExecute(id));
        Proposal memory p = proposals[id];

        proposals[id].status = Status.FINISHED;
        proposalCount = proposalCount.sub(1);
        require(
            p.target.call.value(p.etherValue)(p.bytecode)
        );
        // Fire Events
        emit ProposalTallied(id);

    }

    /**
     * Change arbitrator
     * @param _arbitrator - new arbitrator address
     */
    function changeArbitrator(address _arbitrator) public self {
        require(_arbitrator != address(0));
        arbitrator = _arbitrator;
        emit NewArbitrator(arbitrator);
    }

    function setActiveLimit(uint256 voteLimit) public self {
        require(voteLimit > MIN_VOTE_LIMIT);
        activeVotesLimit = voteLimit;
    }

    function setPause(uint256 date) public self {
        require(
            date >= (now + MIN_DEALINE_PAUSE) ||
            date == 0
        );
        deadline = date;
    }

    function changeStoreOwner(address newOwner) public self {
        voteToken.changeOwner(newOwner);
    }
    // For debugging only
    function kill() public onlyArbitrator {
        selfdestruct(arbitrator);
    }
}
