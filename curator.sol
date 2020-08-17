pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

interface Dgvc {
    function balanceOf(address _owner) external constant returns (uint256 balance);
}
interface Reputation {
    function getGroupRate (uint _rep) external returns (uint8);
    function calculateRep(uint fullPlatformReputation, uint curatorReputation, bool _activation, bool _quorum, bool _uptick, bool _downtick, bool _flag)
    external returns (uint, uint8, uint);
}

interface Limit {
    function setLimits(uint8 _repGroup, uint dgvcBalance) external returns (uint, uint, uint, uint);
    function checkUpdateLimits(uint _limit) external returns (bool, uint);
}

interface CuratorPoolContract {
    function getTransit() external returns(uint, uint);
}


contract Curator is Ownable {

    using SafeMath for *;

    Dgvc public dgvcToken;
    Reputation public reputation;
    Limit public limit;
    CuratorPoolContract public curatorPoolContract;
    address public proposalContractAddress;
    address[] curatorAddresses;


    struct CuratorInstance {
        bool exist;             //to check if curator exists
        uint reputation;        // reputation that accumulating during his work on the platform and impacts on the limits
        uint rewarding;         //accumulated rewarding which should be paid to curator
        uint8 reputationGroup;
        uint limitLike;         //limits
        uint limitFlag;
        uint limitComment;
        uint limitLikeComment;
        uint timestampLimits;   // when limits was done
        uint totalAssessed;     // number of accessed ICOs
        uint totalRated;        // number of rated ICOs
    }

    uint fullPlatformReputation;

    // rate of reputation, depends on was proposal activated or not, reached quorum or not and curator's reaction
    uint activationQuorumUptick; //if proposal was activated, reached the quorum and curator uptick this proposal
    uint noActivationNoQuorumDowntick; //if proposal was not activated, not reached the quorum and curator downtick this proposal
    uint activationNoQuorumDowntick; //if proposal was activated, not reached the quorum and curator downtick this proposal
    uint activationNoQuorumUptick; //if proposal was activated, not reached the quorum and curator uptick this proposal
    uint noActivationNoQuorumUptick; //if proposal was not activated,not reached the quorum and curator uptick this proposal
    uint activationQuorumDowntick; //if proposal was activated, reached the quorum and curator downtick this proposal

    mapping(address => CuratorInstance) curators;
    //mapping(address => uint) balances;

    //Transit public transition;

    //address public proposalController;  //ProposalController contract address

    function Curator() public {
        owner = msg.sender;

        // sum of reputation from all curators on the fullPlatformReputation
        //fullPlatformReputation = 0;

        //reputation rates
        activationQuorumUptick = 7;
        noActivationNoQuorumDowntick = 2;
        activationNoQuorumDowntick = 7;
        activationNoQuorumUptick = 5;
        noActivationNoQuorumUptick = 2;
        activationQuorumDowntick = 5;
    }

    function setCuratorPool(address _curatorPool) public  {
        require(_curatorPool != address(0));
        curatorPoolContract = CuratorPoolContract(_curatorPool);
    }


    function setReputationGroupAddress(address _reputationAddress) public onlyOwner {
        require(_reputationAddress != address(0));
        reputation = Reputation(_reputationAddress);

    }

    function setDgvcContractAddress(address _dgvcTokenAddress) public onlyOwner {
        require(_dgvcTokenAddress != address(0));
        dgvcToken = Dgvc(_dgvcTokenAddress);
    }

    function setLimitContractAddress(address _limitAddress) public onlyOwner {
        require(_limitAddress != address(0));
        limit = Limit(_limitAddress);
    }

    function setProposalContractAddress(address _proposalContractAddress) public onlyOwner {
        require(_proposalContractAddress != address(0));
        proposalContractAddress = _proposalContractAddress;
    }

    modifier onlyProposal() {
        require(msg.sender == proposalContractAddress);
        _;
    }

    function  getBalance() public view returns (uint256) {
        return dgvcToken.balanceOf(msg.sender);
    }



    //create curator with 0 reputation, 0 rewarding and 1 reputation group
    function createCurator() public {
        require(!curators[msg.sender].exist);
        uint256 dgvcBalance = dgvcToken.balanceOf(msg.sender);
        require(dgvcBalance >= 5*1e4);
        if (dgvcBalance >= 5*1e4 && dgvcBalance < 1000*1e4 ) {
            curators[msg.sender] = CuratorInstance(true, 0, 0, 1,  30, 0, 0, 5, now, 0, 0);
        }
        if (dgvcBalance >= 1000*1e4 && dgvcBalance < 2000*1e4) {
            curators[msg.sender] = CuratorInstance(true, 0, 0, 1,  20, 1, 1, 10, now, 0, 0);
        }
        if (dgvcBalance >= 2000*1e4 && dgvcBalance < 10000*1e4) {
            curators[msg.sender] = CuratorInstance(true, 0, 0, 1,  20, 3, 4, 10, now, 0, 0);
        }
        if (dgvcBalance >= 10000*1e4) {
            curators[msg.sender] = CuratorInstance(true, 0, 0, 1,  30, 5, 5, 10000, now, 0, 0);
        }
        curatorAddresses.push(msg.sender);
    }

    //getter for ReputationGroup contract to divide curators for different reputation group
    function getFullReputation() public view returns (uint) {
        return fullPlatformReputation;
    }

    //get curator's reputation from proposal contract in order to store data about reputation of those curators who uptick comment
    function getReputation(address _curator) public view returns (uint) {
        return curators[_curator].reputation;
    }

    //get curator's reputation group from proposal contract in order to store data about reputation of those curators who uptick comment
    function getReputationGroup(address _curator) public view returns (uint) {
        return curators[_curator].reputationGroup;
    }

    //ProposalController call these two functions (calcPos, calcNeg - positive and negative reputation)
    //one by one to calculate reputation and rates of group
    //according to curator's reputation. Also here we calculate 'fullPlatformReputation'
    //groupA = 1
    //groupB = 2
    //groupC = 3
    //groupD = 4

    function calculateReputation(address _curator, bool _activation, bool _quorum, bool _uptick, bool _downtick, bool _flag) external onlyProposal {
        uint256 dgvcBalance = dgvcToken.balanceOf(_curator);
        require(curators[_curator].exist  && dgvcBalance >= 5);
        (curators[_curator].reputation, curators[_curator].reputationGroup, fullPlatformReputation) = reputation.calculateRep(fullPlatformReputation, curators[_curator].reputation, _activation, _quorum, _uptick, _downtick, _flag);
        //reputation.calculateRates
        curators[_curator].reputationGroup = reputation.getGroupRate(curators[_curator].reputation);
    }


    //proposal contract checks curator's limits for 24 hours once he made some action with proposal
    //1 == uptick proposal, 2 == downtick proposal, 3 == flag proposal, 4 == comment, 5 == commentLike
    function limits(address _curator, uint8 _action) external onlyProposal returns (bool) {

        uint256 dgvcBalance = dgvcToken.balanceOf(_curator);
        require(curators[_curator].exist  && dgvcBalance >= 5);

        if (now < (curators[_curator].timestampLimits + 24 hours)) {
            return subtractLimits(_curator, _action);
        }

        if (now >= (curators[_curator].timestampLimits + 24 hours)) {
            curators[_curator].timestampLimits = now;  //if timestamp is more then + 24 hours we set timestamp 'now'
            (curators[_curator].limitLike, curators[_curator].limitFlag, curators[_curator].limitComment,
            curators[_curator].limitLikeComment) = limit.setLimits(curators[_curator].reputationGroup, dgvcBalance);     //and call function to refresh limits
            return subtractLimits(_curator, _action);
        }
    }

    function subtractLimits(address _curator, uint8 _action) internal returns (bool){
        bool hasLimit;
        uint newLimit;
        if (_action == 1 || _action == 2) { //then we need to subtract of limits exact action
            (hasLimit, newLimit) = limit.checkUpdateLimits(curators[_curator].limitLike);
            curators[_curator].limitLike = newLimit;
            return hasLimit;
        }
        if (_action == 3) {
            (hasLimit, newLimit) = limit.checkUpdateLimits(curators[_curator].limitFlag);
            curators[_curator].limitFlag = newLimit;
            return hasLimit;
        }
        if (_action == 4) {
            (hasLimit, newLimit) = limit.checkUpdateLimits(curators[_curator].limitComment);
            curators[_curator].limitComment = newLimit;
            return hasLimit;
        }
        if (_action == 5) {
            (hasLimit, newLimit) = limit.checkUpdateLimits(curators[_curator].limitLikeComment);
            curators[_curator].limitLikeComment = newLimit;
            return hasLimit;
        }
    }



    // get limits to place in ui by curator's address
    function getLimits(address _curator) public view returns (uint, uint, uint, uint) {
        require(curators[_curator].exist);
        return (
        curators[_curator].limitLike,
        curators[_curator].limitFlag,
        curators[_curator].limitComment,
        curators[_curator].limitLikeComment
        );
    }

    // check if curator is existed
    function checkExistence(address _curator) external view returns(bool) {
        uint256 dgvcBalance = dgvcToken.balanceOf(_curator);
        if (curators[_curator].exist && dgvcBalance >= 5) {
            return true;
        } else {
            return false;
        }
    }

    function getCurators() public view returns(address[]) {
        return curatorAddresses;
    }

    // 1 == rated, 2 == accessed
    function addRateAccessCount(uint8 _type, address _curator) external onlyProposal {
        if (_type == 1) {
            curators[_curator].totalRated += 1;
        } else if (_type == 2) {
            curators[_curator].totalAssessed += 1;
        } else {
            revert();
        }
    }

    function getRatedAccessedAmount(address _curator) public view returns(uint, uint) {
        return(
            curators[_curator].totalRated,
            curators[_curator].totalAssessed
        );
    }

}
