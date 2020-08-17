pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

interface OracleContract {
    function getPrice() external view returns(uint);
}

interface QuorumContract {
    function checkCitizenQuorum(uint _upVotes, uint _downVotes) external view returns(bool);
    function checkCuratorsQuorum(uint _upTicks, uint _downTicks) external view returns(bool);
}

interface CuratorContract {
    function limits(address _curator, uint8 _action) external returns (bool);
    function getReputation(address _curator) external view returns (uint);
    function calculateReputation(address _curator, bool _activation, bool _quorum, bool _uptick, bool _downtick, bool _flag) external;
    function getReputationGroup(address _curator) external view returns (uint);
    function addRateAccessCount(uint8 _type, address _curator) external;
}

interface CuratorRewardContract {
    function calcEffort(uint _effort, address _curator) external;
}

interface DaoSA {
    function fundProposal(uint _requestedAmount, address _submitter) external returns(uint);
    function fundraising(uint _amount, address _submitter) external;
}

interface Growth {
    function fundraising(uint _requestedAmount, uint _fundraisedAmount, address _submitter) external;
    function fundedFromFund(uint _requestedAmount) external returns (uint);
    function payProposal(uint _pay, address _submitter) external;
}

interface Fund {
    function isFund() external view returns(bool);
}

interface DgvcContract {
    function balanceOf(address _owner) external constant returns (uint256 balance);
}

contract Proposals is Ownable {

    using SafeMath for uint;

    event newProposal(uint _id);
    event statusChanged(uint _id, Status _status);

    OracleContract public oracle;
    CuratorContract public curator;
    QuorumContract public quorum;
    CuratorRewardContract public curatorEffort;
    DaoSA public daoSA;
    Fund public fund; // Fork Funds
    DgvcContract public dgvc;
    Growth public growth; // Daoact Growth Fund

    address public growthFund;
    address public daoactFund; // Daoact Social Accountability
    address public curatorPool;

    // tunable
    uint public minVotesNumber;
    uint public submissionFee = 1 ether;

    uint public proposalIndex;
    //mapping(address => bool) alreadySubmit;
    mapping(uint => Proposal) proposals;

    struct Proposal {
        uint id;
        uint timestamp;
        Status status;
        address submitter;
        string title;
        string short;
        string description;
        string videoLink;
        string documentsLink;
        uint requestedAmount;
        uint receivedAmount;
        uint receivedDirect;
        uint upTicks;
        uint downTicks;
        uint upVotes;
        uint downVotes;
        uint flags;
        bool allowedToFund;
        bool activatedByCurators;
        bool quorumReached;
        uint commentIndex;
        mapping (uint => Comment) comments;
        mapping (address => Tick) ticks; // curator's ticks storage
        mapping (address => bool) voted; // citizen's votes storage
        mapping (address => bool) reputationGot; // citizen's votes storage

        uint startINITIAL;
        uint endINITIAL;
        uint startICO;
        uint endICO;
        uint startPRE;
        uint endPRE;

        uint8 discount;
        string telegram;
        string sector;
        bool kys;
        bool aml;
        bool mvp;
    }

    // curator's comment
    struct Comment {
        uint id;
        uint timestamp;
        address author;
        string text;
        uint upticksCounter;
        bool existed;
        mapping (address => bool) upTicked;
    }

    // curator's tick
    struct Tick {
        bool upTick;
        bool downTick;
        bool flag;
        bool reacted;
    }

    enum Status { curation, voting, funding, directFunding, closed }

    // *** CONSTRUCTOR *** //

    function Proposals() public {
        owner = msg.sender;
        minVotesNumber = 1;
    }

    // *** MODIFIERS *** //

    modifier hasStatus(uint _index, Status _status) {
        require(proposals[_index].status == _status);
        _;
    }

    modifier onlyCurator(address _curator, uint8 _tick) {
        require(curator.limits(_curator, _tick));
        _;
    }

    modifier onlyFund() {
        require(msg.sender == growthFund || msg.sender == daoactFund);
        _;
    }

    modifier nonZeroAddress(address _address) {
        require(_address != address(0));
        _;
    }

    // *** STATE FUNCTIONS *** //

    function setOracleAddress(address _newOracleAddress) public onlyOwner nonZeroAddress(_newOracleAddress) {
        oracle = OracleContract(_newOracleAddress);
    }

    function setCuratorAddress(address _newCuratorAddress) public onlyOwner nonZeroAddress(_newCuratorAddress) {
        curator = CuratorContract(_newCuratorAddress);
    }

    function setQuorumAddress(address _newQuorumAddress) public onlyOwner nonZeroAddress(_newQuorumAddress) {
        quorum = QuorumContract(_newQuorumAddress);
    }

    function setGrowthFundAddress(address _newGrowthFundAddress) public onlyOwner nonZeroAddress(_newGrowthFundAddress) {
        growthFund = _newGrowthFundAddress;
    }

    function setDaoSaAddress(address _newSaAddress) public onlyOwner nonZeroAddress(_newSaAddress) {
        daoSA = DaoSA(_newSaAddress);
    }

    function setDaoactFundAddress(address _newFundAddress) public onlyOwner nonZeroAddress(_newFundAddress) {
        daoactFund = _newFundAddress;
    }


    function setMinVotesNumber(uint _newVotesNumber) public onlyOwner {
        minVotesNumber = _newVotesNumber;
    }

    function setSubmissionFee(uint _newSubmissionFeeInUSD) public onlyOwner {
        submissionFee = _newSubmissionFeeInUSD;
    }

    function setCuratorPoolAddress(address _curatorPoolAddress) public onlyOwner {
        curatorPool = _curatorPoolAddress;
    }

    function setGrowthFundContract(address _growth) public onlyOwner {
        growth = Growth(_growth);
        growthFund = _growth;
    }

    function setCuratorEffortContract(address _curatorEffortContract) public onlyOwner {
        curatorEffort = CuratorRewardContract(_curatorEffortContract);
    }

    function setDgvcContract(address _dgvcContract) public onlyOwner {
        dgvc = DgvcContract(_dgvcContract);
    }

    function submit(string _title, string _short, string _description,  string _videoLink, string _documentsLink,
                    string _telegram, string _sector, uint _requestedAmount,
                    uint[] _dates, uint8 _discount, bool[] _kysamlmvp) public payable {

        uint index = proposalIndex;
        proposalIndex +=1;

        require(
            bytes(_title).length > 0 &&
            bytes(_description).length > 0 &&
            bytes(_videoLink).length > 0 &&
            bytes(_documentsLink).length > 0 &&
            _requestedAmount > 0 &&
            msg.value == submissionFee
        );

        curatorPool.transfer(msg.value);

        proposals[index] = Proposal(
            index,
            now,
            Status.curation,
            msg.sender,
            _title,
            _short,
            _description,
            _videoLink,
            _documentsLink,
            _requestedAmount,
            0, 0, 0, 0, 0, 0, 0, false, false, false, 0,
            _dates[0],
            _dates[1],
            _dates[2],
            _dates[3],
            _dates[4],
            _dates[5],
            _discount,
            _telegram,
            _sector,
            _kysamlmvp[0],
            _kysamlmvp[1],
            _kysamlmvp[2]
        );

        emit newProposal(index);

    }

    // curators ticks
    // 1 == upTick proposal, 2 == downTick proposal, 3 == flag proposal
    function tick(uint _proposalIndex, uint8 _tick) public hasStatus(_proposalIndex, Status.curation) onlyCurator(msg.sender, _tick) {

       require(
            !proposals[_proposalIndex].ticks[msg.sender].upTick &&
            !proposals[_proposalIndex].ticks[msg.sender].downTick &&
            !proposals[_proposalIndex].ticks[msg.sender].flag &&
            !proposals[_proposalIndex].ticks[msg.sender].reacted
       );

       proposals[_proposalIndex].ticks[msg.sender].reacted = true;
       uint group = curator.getReputationGroup(msg.sender);
       uint balance = dgvc.balanceOf(msg.sender);

       curator.addRateAccessCount(1, msg.sender);

       if (_tick == 1) {
            if ( group >= 3 || balance >= 2000) {
                proposals[_proposalIndex].upTicks += 1;
            }
            proposals[_proposalIndex].ticks[msg.sender].upTick = true;
       } else if (_tick == 2) {
            if ( group >= 3 || balance >= 2000 ) {
                proposals[_proposalIndex].downTicks += 1;
            }
            proposals[_proposalIndex].ticks[msg.sender].downTick = true;
       } else if (_tick == 3) {
            if ( group >= 3 || balance >= 2000 ) {
                proposals[_proposalIndex].flags += 1;
            }
            proposals[_proposalIndex].ticks[msg.sender].flag = true;
            if (proposals[_proposalIndex].flags == 5) {
                proposals[_proposalIndex].status = Status.closed;
                emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);
            }
       } else {
            revert();
       }

       if (now > proposals[_proposalIndex].timestamp.add(200 days)) {
           if (quorum.checkCuratorsQuorum(proposals[_proposalIndex].upTicks, proposals[_proposalIndex].downTicks)) {
               proposals[_proposalIndex].activatedByCurators = true;
               proposals[_proposalIndex].status = Status.voting;
               emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);
           } else {
               proposals[_proposalIndex].status = Status.closed;
               emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);
           }
       }
    }

    function commentProposal(uint _proposalIndex, string _text) public hasStatus(_proposalIndex, Status.curation) onlyCurator(msg.sender, 4) {
        require(bytes(_text).length > 0);
        curator.addRateAccessCount(2, msg.sender);
        uint index = proposals[_proposalIndex].commentIndex;
        proposals[_proposalIndex].commentIndex += 1;
        proposals[_proposalIndex].comments[index] = Comment(index, now, msg.sender, _text, 0, true);
    }

    function tickComment(uint _proposalIndex, uint _commentIndex) public hasStatus(_proposalIndex, Status.curation) onlyCurator(msg.sender, 5) {
        require(
            !proposals[_proposalIndex].comments[_commentIndex].upTicked[msg.sender] &&
            proposals[_proposalIndex].comments[_commentIndex].author != msg.sender &&
            proposals[_proposalIndex].comments[_commentIndex].existed
        );
        proposals[_proposalIndex].comments[_commentIndex].upTicked[msg.sender] = true;
        proposals[_proposalIndex].comments[_commentIndex].upticksCounter += 1;

        uint reputation = curator.getReputation(msg.sender);
        if (reputation > 0) {
            curatorEffort.calcEffort(reputation, proposals[_proposalIndex].comments[_commentIndex].author);
        }
    }

    // citizen vote
    // 1 == vote up, 2 == vote down
    function vote(uint _proposalIndex, uint _vote) public payable hasStatus(_proposalIndex, Status.voting) {

        require(proposals[_proposalIndex].voted[msg.sender] == false);

        proposals[_proposalIndex].voted[msg.sender] = true;
        growthFund.transfer(msg.value);

        if (_vote == 1) {
            proposals[_proposalIndex].upVotes += 1;
        } else if (_vote == 2) {
            proposals[_proposalIndex].downVotes += 1;
        } else {
            revert();
        }

        if (now > proposals[_proposalIndex].timestamp.add(20 minutes).add(20 minutes)) {
           if (proposals[_proposalIndex].upVotes.add(proposals[_proposalIndex].downVotes) >= minVotesNumber) {
                if (quorum.checkCitizenQuorum(proposals[_proposalIndex].upVotes, proposals[_proposalIndex].downVotes)) {

                    proposals[_proposalIndex].status = Status.funding;
                    proposals[_proposalIndex].quorumReached = true;

                    proposals[_proposalIndex].receivedAmount = growth.fundedFromFund(proposals[_proposalIndex].requestedAmount);
                    proposals[_proposalIndex].status = Status.directFunding;

               } else {
                   proposals[_proposalIndex].status = Status.closed;
               }
           } else {
                proposals[_proposalIndex].status = Status.closed;
           }
           emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);
       }
    }

    //only for external fund forks
    function fund(uint _proposalIndex) external payable hasStatus(_proposalIndex, Status.funding) {
        fund = Fund(msg.sender);
        require(fund.isFund());

        proposals[_proposalIndex].status = Status.closed;
        proposals[_proposalIndex].submitter.transfer(msg.value);
        proposals[_proposalIndex].receivedAmount = msg.value;

    }

    // Direct funding
    function directFunding(uint _proposalIndex, uint _fundDirect) external  onlyFund {

        uint fundDirect = _fundDirect;
        proposals[_proposalIndex].receivedDirect = proposals[_proposalIndex].receivedDirect.add(fundDirect);

        uint allFunds = proposals[_proposalIndex].receivedDirect.add(proposals[_proposalIndex].receivedAmount);

        if (allFunds >= proposals[_proposalIndex].requestedAmount) {
            growth.payProposal(proposals[_proposalIndex].requestedAmount, proposals[_proposalIndex].submitter);
            proposals[_proposalIndex].status = Status.closed;
            emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);

        } else if (now > proposals[_proposalIndex].timestamp.add(200 days).add(20 minutes).add(20 minutes)) {
            uint max_payout = proposals[_proposalIndex].requestedAmount.div(2);
            if (proposals[_proposalIndex].receivedDirect < max_payout) {
                proposals[_proposalIndex].status = Status.closed;
                emit statusChanged(_proposalIndex, proposals[_proposalIndex].status);
            } else if (proposals[_proposalIndex].receivedDirect >= max_payout) {
                growth.payProposal(allFunds, proposals[_proposalIndex].submitter);
            }
        }

    }


    // *** GETTERS *** //

    function getProposalTimestamp(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].timestamp;
    }

    function getProposalStatus(uint _proposalIndex) public view returns(Status) {
        return proposals[_proposalIndex].status;
    }

    function getProposalSubmitter(uint _proposalIndex) public view returns(address) {
        return proposals[_proposalIndex].submitter;
    }

    function getProposalTitle(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].title;
    }

    function getShortDescription(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].short;
    }

    function getProposalDescription(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].description;
    }

    function getProposalVideoLink(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].videoLink;
    }

    function getProposalDocumentsLink(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].documentsLink;
    }

    function getRequestedAmount(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].requestedAmount;
    }

    function getReceivedAmount(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].receivedAmount;
    }

    function getDirectAmountReceived(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].receivedDirect;
    }

    function getProposalUpTicks(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].upTicks;
    }

    function getProposalDownTicks(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].downTicks;
    }

    function getProposalUpVotes(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].upVotes;
    }

    function getProposalDownVotes(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].downVotes;
    }

    function getProposalFlags(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].flags;
    }

    function isProposalAllowedToFund(uint _proposalIndex) public view returns(bool) {
        return proposals[_proposalIndex].allowedToFund;
    }

    function getCommentIndex(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].commentIndex;
    }

    function getProposalId(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].id;
    }

    function getReceivedDirect(uint _proposalIndex) public view returns(uint) {
        return proposals[_proposalIndex].receivedDirect;
    }

    function isReputationGot(uint _proposalIndex, address _curator) public view returns(bool) {
        return proposals[_proposalIndex].reputationGot[_curator];
    }

    function getTelegram(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].telegram;
    }

    function getSector(uint _proposalIndex) public view returns(string) {
        return proposals[_proposalIndex].sector;
    }

    function getKycAmlMvp(uint _proposalIndex) public view returns(bool, bool, bool) {
        return (
            proposals[_proposalIndex].kys,
            proposals[_proposalIndex].aml,
            proposals[_proposalIndex].mvp
        );
    }

    function getDates(uint _proposalIndex) public view returns(uint, uint, uint, uint, uint, uint) {
        return (
            proposals[_proposalIndex].startINITIAL,
            proposals[_proposalIndex].endINITIAL,
            proposals[_proposalIndex].startPRE,
            proposals[_proposalIndex].endPRE,
            proposals[_proposalIndex].startICO,
            proposals[_proposalIndex].endICO
        );
    }

    function getComment(uint _proposalIndex, uint _commentIndex) public view returns(uint, uint, address, string, uint) {
        return (
            proposals[_proposalIndex].comments[_commentIndex].id,
            proposals[_proposalIndex].comments[_commentIndex].timestamp,
            proposals[_proposalIndex].comments[_commentIndex].author,
            proposals[_proposalIndex].comments[_commentIndex].text,
            proposals[_proposalIndex].comments[_commentIndex].upticksCounter
        );
    }

    function isCuratorReputationExisted(uint _proposalIndex, address _curator) public view returns(bool) {
        return proposals[_proposalIndex].ticks[_curator].reacted;
    }

    function getCuratorReputation(uint _proposalIndex) public {
        if (!proposals[_proposalIndex].reputationGot[msg.sender] && proposals[_proposalIndex].status == Status.closed &&
        !proposals[_proposalIndex].activatedByCurators) {
            proposals[_proposalIndex].reputationGot[msg.sender] = true;
            curator.calculateReputation(
                msg.sender, proposals[_proposalIndex].activatedByCurators, proposals[_proposalIndex].quorumReached,
                proposals[_proposalIndex].ticks[msg.sender].upTick,
                proposals[_proposalIndex].ticks[msg.sender].downTick,
                proposals[_proposalIndex].ticks[msg.sender].flag
            );
        } else {
            require(!proposals[_proposalIndex].reputationGot[msg.sender] && proposals[_proposalIndex].status != Status.voting && proposals[_proposalIndex].status != Status.curation);
            proposals[_proposalIndex].reputationGot[msg.sender] = true;
            curator.calculateReputation(
                msg.sender, proposals[_proposalIndex].activatedByCurators, proposals[_proposalIndex].quorumReached,
                proposals[_proposalIndex].ticks[msg.sender].upTick,
                proposals[_proposalIndex].ticks[msg.sender].downTick,
                proposals[_proposalIndex].ticks[msg.sender].flag
            );
        }
    }

    function getDiscount(uint _proposalIndex) public view returns(uint8) {
        return proposals[_proposalIndex].discount;
    }

}
