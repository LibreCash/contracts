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
    
    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
     * @dev Total number of tokens in existence
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

    /**
     * @dev Burns a specific amount of tokens.
     * @param _to The address that will burn tokens.
     * @param _amount The amount of token to be burned.
     */
    function burn(address _to, uint256 _amount) onlyOwner public  {
        require(_amount <= balances[_to]);
        balances[_to] = balances[_to].sub(_amount);
        totalSupply_ = totalSupply_.sub(_amount);
    }

    /**
     * @dev Allows the current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
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
        mapping (address => bool) isVoted;
    }

    uint256 public proposalCount;
    Proposal[] public proposals;
}


/**
 * The voting system
 */
contract VotingSystem is ProposalSystem {
    using SafeMath for uint256;

    struct VoteItem {
        uint256 proposal;
        bool support;
    }

    modifier active {
        require(
            deadline == 0 ||
            deadline >= now
        );
        _;
    }

    mapping(address => mapping(uint256 => uint256)) internal fieldOf; // proposal => field
    mapping (address => VoteItem[]) internal votesOf;

    TokenStore public voteToken;
    ERC20 public govToken;

    uint256 public deadline = 0;
    uint256 constant MAX_UINT = 2 ** 256 - 1;
    uint256 constant MIN_VOTE_LIMIT = 10;
    uint256 public activeVotesLimit = 10;
    uint256 constant MINIMAL_VOTE_BALANCE = 2000 * 10 ** 18;
    uint256 public minVotes = MINIMAL_VOTE_BALANCE;

    /**
     * @dev Checks the proposal status.
     * @param p Proposal.
     * @param s Status.
     */
    function its(Proposal p, Status s) internal pure returns (bool) {
        return p.status == s;
    }

    /**
     * @dev Locks tokens for voting.
     * @param _amount Token amount.
     */
    function lock(uint256 _amount) public {
        voteToken.mint(msg.sender, _amount);
        recalcProposals(_amount, true);
        govToken.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @dev Unlocks tokens for voting.
     * @param _amount Token amount.
     */
    function unlock(uint256 _amount) public {
        voteToken.burn(msg.sender, _amount);
        recalcProposals(_amount, false);
        govToken.transfer(msg.sender, _amount);
    }

    /**
     * @dev User vote power.
     */
    function votePower() public view returns (uint256) {
        return voteToken.balanceOf(msg.sender);
    }

    /**
     * @dev Allows to take back user vote.
     * @param id Proposal ID.
     */
    function unvote(uint256 id) public {
        uint field = fieldOf[msg.sender][id];
        Proposal storage p = proposals[id];

        require(
            p.isVoted[msg.sender] &&
            its(p, Status.ACTIVE)
        );
        recalcProposal(field, votePower(), false);
        proposals[id].isVoted[msg.sender] = false;
        votesOf[msg.sender][field].proposal = MAX_UINT;
    }

    /**
     * @dev Modifies proposal votes; internal.
     * @param i Vote flag id.
     * @param _amount Vote token amount.
     * @param increase Flag, increase or decrease.
     */
    function recalcProposal(uint256 i, uint256 _amount, bool increase) internal {
        uint256 current = votesOf[msg.sender][i].proposal;
        if (its(proposals[current], Status.ACTIVE) && proposals[current].deadline > now) {
            if (votesOf[msg.sender][i].support) {
                proposals[current].yea = increase ?
                    proposals[current].yea.add(_amount) :
                    proposals[current].yea.sub(_amount);
            } else {
                proposals[current].nay = increase ?
                    proposals[current].nay.add(_amount) :
                    proposals[current].nay.sub(_amount);
            }
        }
    }

    /**
     * @dev Modifies all user's proposal votes; internal.
     * @param _amount Vote token amount.
     * @param increase Flag, increase or decrease.
     */
    function recalcProposals(uint256 _amount, bool increase) internal {
        for (uint256 i = 0; i < votesOf[msg.sender].length; i++) {
            recalcProposal(i, _amount, increase);
        }
    }
    
    /**
     * @dev Returns if vote flag is unused now; internal.
     * @param id Vote flag id.
     */
    function isFieldFree(uint256 id) internal view returns (bool) {
        uint256 proposal = votesOf[msg.sender][id].proposal;
        return proposal == MAX_UINT ||
                !its(proposals[proposal], Status.ACTIVE) ||
                proposals[proposal].deadline < now ||
                !proposals[proposal].isVoted[msg.sender];
    }

    /**
     * @dev Returns free vote flag.
     */
    function getFreeField() public view returns (uint256) {
        uint256 len = votesOf[msg.sender].length;
        if (len < activeVotesLimit) return len;
        for (uint256 i = 0; i < len; i++) {
            if (isFieldFree(i)) return i;
        }
        return MAX_UINT; // not revert() to make a user understand;
                         //MAX_UINT field will make vote() fail anyway: MAX_UINT just can't be below any UINT
    }
}


/**
 * The shareholder association contract itself
 */
contract Association is VotingSystem {
    struct Vote {
        bool inSupport;
        address voter;
    }

    event Voted(uint256 id, bool position, uint256 power);
    event RulesChange(address token, uint256 quorum, uint256 period, uint256 votes);
    event NewArbitrator(address arbitrator);

    uint256 constant MIN_DEADLINE_PAUSE = 14 days;

    modifier only(address _sender) {
        require(msg.sender == _sender);
        _;
    }

    modifier voters {
        require(canVote());
        _;
    }

    address public arbitrator;
    uint256 public minQuorum;
    uint256 public minPeriod;

    /**
     * @dev Returns if user can vote.
     */
    function canVote() public view returns(bool) {
        return voteToken.balanceOf(msg.sender) >= minVotes;
    }

    /**
     * @dev Returns if user can execute proposal.
     * @param id Proposal id.
     */
    function canExecute(uint256 id) public view returns (bool) {
        Proposal storage p = proposals[id];
        uint256 quorum = p.yea + p.nay;
        return (
            its(p, Status.ACTIVE) &&
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
     * @dev Gets a balance of tokens.
     */
    function unheldBalance() public view returns(uint256) {
        return govToken.balanceOf(msg.sender);
    }

    /**
     * @dev Gets a length of proposals.
     */
    function proposalsLength() public view returns (uint256) {
        return proposals.length;
    }

    /**
     * @dev Gets data about proposal.
     * @param id Proposal ID.
     */
    function getVotingData(uint256 id) public view returns (uint256, uint256, bool, uint256) {
        Proposal storage p = proposals[id];
        return (p.yea, p.nay, p.isVoted[msg.sender], p.deadline);
    }

    /**
     * @dev Veto proposal.
     * @param id Proposal ID.
     */
    function veto(uint256 id) public only(arbitrator) {
        Proposal memory proposal = proposals[id];
        require(its(proposal, Status.ACTIVE));

        proposals[id].status = Status.BLOCKED;
        proposalCount = proposalCount.sub(1);
        proposal.initiator.transfer(proposal.etherValue);
        emit ProposalBlocked(id, arbitrator);
    }

    /**
     * @dev Cancels proposal.
     * @param id Proposal ID.
     */
    function cancel(uint256 id) public voters {
        Proposal storage p = proposals[id];
        require(!canExecute(id));

        p.status = Status.CANCELLED;
        proposalCount = proposalCount.sub(1);
        p.initiator.transfer(p.etherValue);
        emit ProposalCancelled(id, msg.sender);
    }

    /**
     * @dev Change voting rules
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
    function changeRules(ERC20 gov, uint256 _minQuorum, uint256 _minPeriod, uint256 _minVotes) public only(arbitrator) {
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
     * @dev Add Proposal
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

    /**
     * @dev Computes deadline to use in newProposal; internal.
     * @param period Provided period.
     */
    function getDeadline(uint256 period) internal view returns (uint256) {
        return now.add((period >= minPeriod) ? period : minPeriod);
    }

    /**
     * @dev Short version of voting function.
     *
     * @param id Proposal ID.
     * @param support Either in favor or against it.
     */
    function vote(uint256 id, bool support) public {
        vote(id, support, getFreeField());
    }

    /**
     * @dev Voting function.
     *
     * Vote `supportsProposal? in support of : against` proposal #`id`
     *
     * @param id Proposal ID.
     * @param support Either in favor or against it.
     * @param field Vote field.
     */
    function vote(uint256 id, bool support, uint256 field) public active voters {
        Proposal storage p = proposals[id];

        require(its(p, Status.ACTIVE) && !p.isVoted[msg.sender] && now < p.deadline && field < activeVotesLimit);
        p.isVoted[msg.sender] = true;

        uint256 power = votePower();

        if (support) p.yea = p.yea.add(power);
        else p.nay = p.nay.add(power);

        if (field >= votesOf[msg.sender].length) {
            votesOf[msg.sender].length++;
        } else {
            require(isFieldFree(uint256(field)));
        }

        votesOf[msg.sender][field] = VoteItem({proposal: id, support: support});
        fieldOf[msg.sender][id] = field;

        emit Voted(id, support, power);
    }

    /**
     * @dev Executes proposal and finish vote.
     *
     * Count the votes proposal #`id` and execute it if approved
     *
     * @param id Proposal ID.
     */
    function execute(uint256 id) public active {
        require(canExecute(id));
        Proposal memory p = proposals[id];

        proposals[id].status = Status.FINISHED;
        proposalCount = proposalCount.sub(1);
        require(
            p.target.call.value(p.etherValue)(p.bytecode)
        );
        emit ProposalTallied(id);
    }

    /**
     * @dev Changes arbitrator.
     * @param _arbitrator New arbitrator address.
     */
    function changeArbitrator(address _arbitrator) public only(address(this)) {
        require(_arbitrator != address(0));
        arbitrator = _arbitrator;
        emit NewArbitrator(arbitrator);
    }

    /**
     * @dev Sets limit of active votes for one user.
     * @param voteLimit The new limit.
     */
    function setActiveLimit(uint256 voteLimit) public only(address(this)) {
        require(voteLimit >= MIN_VOTE_LIMIT);
        activeVotesLimit = voteLimit;
    }

    /**
     * @dev Sets pause.
     * @param date The timestamp "from" (when the pause shall start).
     */
    function setPause(uint256 date) public only(address(this)) {
        require(
            date >= (now + MIN_DEADLINE_PAUSE) ||
            date == 0
        );
        deadline = date;
    }

    /**
     * @dev Allows the current owner to set the new owner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public only(address(this)) {
        voteToken.transferOwnership(newOwner);
    }
}
