## Development requirements specification for Smart contract for cooperative decision making and fund raising (DAO)

**Draft**

**_System purpose:_** the system under design is meant for decision making and carrying out within Libre ecosystem particularly for LibreBank (ComplexBank) emission contract parametric control.

These decisions involve queue processing time setting, processing intervals setting, oracles management, purchase and sale limits setting, orders canceling, purchase and sale fee setting, scheduler assignation, change of ownership for all contracts, change of bank and DAO contracts.

Decision making is based on the principle of advancement of proposals, voting and further execution (or refusal). 

**System functionality:**

1. Proposals (tasks) placement 

2. Proposals list reading

3. Voting for a proposal. Binary voting (yes\no). Libre tokens balance serves as a vote supplying.

4. Proposal execution upon voting completion provided there are more **"YES"** votes than **“NO”** (1 vote = amount of tokens) and the total amount of tokens reserved for voting is not bigger than a certain % of all tokens.

**Background:**

1. Any shareholder who has no less than **MINIMAL_VOTE_BALANCE **tokens can create a proposal. The proposal must have description and debate period during which all shareholders can vote. Proposal creation triggers notification event for all shareholders.

2. Upon creation of a proposal, a unique **ID **is assigned to it. Any shareholder can find the proposal by this ID and vote "YES" or “NO”. No voter can change his vote.

3. There is a limit for all proposals: the minimum amount of tokens reserved in the voting for decision making.

4. When votes are counted all **YES **and **NO **votes are recognized. Making the decision a shareholder chooses **YES **or **NO **vote and supplies it with his tokens. Thus, a shareholder with more tokens has more power in the voting.

5. A proposal can be executed only after the debate period and under condition that there are more **YES **votes than **NO**. The amount of **YES **and **NO **tokens is calculated during the final vote counting, which reduces the risk of voter fraud and tokens "transfer"

