pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

interface CuratorRewardingContract {
    function setEfforts(address _curator) external returns (bool);
    function getTransitEfforts(address _curator) external view returns (uint, uint, uint);
    function calcEffort(uint _effort, address _curator) external;
    function getDatePaid(address curator) external returns (uint);
    function setTransitEfforts(address _curator) external returns (bool);
    function setRewardPaid(address _curator, uint _rewardPaid) external;
}

interface CuratorContract {
    function checkExistence(address _curator) external view returns(bool);
}

contract CuratorPool is Ownable {

    using SafeMath for *;

    CuratorRewardingContract public curatorRewardingContract;
    CuratorContract public curatorContract;

    uint public rewardingPoolA;
    uint public rewardingPoolB;
    uint public rewardingPoolC;

    uint public oneEffortA;
    uint public oneEffortB;
    uint public oneEffortC;

    uint public timestamp;

    struct Transit {
        uint timestamp;
        uint balance;
    }

    Transit public transit;

    function CuratorPool() public {
        owner = msg.sender;
        timestamp = now;
    }

    function setCuratorRewardingContractAddress(address _curatorRewardingContract) public onlyOwner {
        require(_curatorRewardingContract != address(0));
        curatorRewardingContract = CuratorRewardingContract(_curatorRewardingContract);
    }

    function setCuratorContractAddress(address _curatorContract) public onlyOwner {
        require(_curatorContract != address(0));
        curatorContract = CuratorContract(_curatorContract);
    }


    function setTransit() external{
        timestamp = now;
        transit.timestamp = now;
        transit.balance = address(this).balance;
pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

interface CuratorPoolContract {
    function setTransit() external;
    function getTimestamp() external view returns(uint);
    function getTransit() external view returns(uint, uint);
    function calculateGroups() external;
    function calculateOneEffort(uint fullEffortTransitA, uint fullEffortTransitB, uint fullEffortTransitC) external returns (uint,uint,uint);
    //    function calculateGroups() internal;
}

interface Dgvc {
    function balanceOf(address _owner) external constant returns (uint256 balance);
}

interface CuratorContractInstance {
    function checkExistence(address _curator) external view returns(bool);
}

contract CuratorRewardEffort is Ownable {

    using SafeMath for *;

    CuratorContractInstance public curatorContractInstance;
    Dgvc public dgvcToken;
    CuratorPoolContract public curatorPool;
    address public curatorAddress;
    address public proposalContract;
    address public poolContract;


    uint fullEffortA;  //group A according to the reputation
    uint fullEffortB;  //group B according to the reputation
    uint fullEffortC;  //group C according to the reputation

    struct Transit {
        uint fullEffortTransitA;  //group A according to the reputation
        uint fullEffortTransitB;  //group B according to the reputation
        uint fullEffortTransitC;  //group C according to the reputation

    }

    struct CuratorEffort {
        uint effortA;
        uint effortB;
        uint effortC;
        uint rewarding;
        uint datePaid;
        uint rewardPaid;
        uint transitEffortA;
        uint transitEffortB;
        uint transitEffortC;
    }

    uint group60;
    uint group30;
    uint group10;

    Transit transit;
    mapping(address => CuratorEffort) curatorEffort;

    function CuratorRewardEffort() public {
        owner = msg.sender;
    }

    function setDgvcContractAddress(address _dgvcTokenAddress) public onlyOwner {
        require(_dgvcTokenAddress != address(0));
        dgvcToken = Dgvc(_dgvcTokenAddress);
    }

    function setCuratorPoolContractAddress(address _curatorPoolContract) public onlyOwner {
        require(_curatorPoolContract != address(0));
        curatorPool = CuratorPoolContract(_curatorPoolContract);
        poolContract = _curatorPoolContract;
    }

    function setCuratorContractAddress(address _curatorContract) public onlyOwner {
        require(_curatorContract != address(0));
        curatorContractInstance = CuratorContractInstance(_curatorContract);
        curatorAddress = _curatorContract;
    }

    function setProposalContractAddress(address _proposalContract) public onlyOwner {
        require(_proposalContract != address(0));
        proposalContract = _proposalContract;
    }

    modifier onlyPool() {
        require(msg.sender == poolContract);
        _;
    }

    modifier onlyPoolOrProposal() {
        require(msg.sender == poolContract || msg.sender == proposalContract);
        _;
    }

    modifier onlyPoolOrInternal() {
        require(msg.sender == poolContract || msg.sender == address(this));
        _;
    }

    modifier onlyProposal() {
        require(msg.sender == proposalContract);
        _;
    }
    //calculate curator's effort
    function calcEffort(uint _effort, address _curator) external onlyPoolOrProposal  {
        require(curatorContractInstance.checkExistence(_curator));
        uint timestamp;

        (timestamp) = curatorPool.getTimestamp();
        uint256 dgvcBalance = dgvcToken.balanceOf(_curator);

        if (now <= timestamp.add(1 days)) {
            accumulateEffort(dgvcBalance, _curator, _effort);
        }
        if (now > timestamp.add(1 days)) {
            curatorPool.setTransit();
            require(setTransitEfforts(_curator));
            setFullEffort();
            curatorPool.calculateGroups();
            curatorPool.calculateOneEffort(transit.fullEffortTransitA, transit.fullEffortTransitB, transit.fullEffortTransitC);
            accumulateEffort(dgvcBalance, _curator, _effort);
        }
    }


    function accumulateEffort(uint dgvcBalance, address _curator, uint _effort) internal {
        if (dgvcBalance >= 5*1e4 && dgvcBalance <= 1999*1e4) {
            curatorEffort[_curator].effortC = curatorEffort[_curator].effortC.add(_effort);
            fullEffortC = fullEffortC.add(_effort);
        }
        if (dgvcBalance >= 2000*1e4 && dgvcBalance <= 19999*1e4) {
            curatorEffort[_curator].effortB = curatorEffort[_curator].effortB.add(_effort);
            fullEffortB = fullEffortB.add(_effort);
        }
        if (dgvcBalance >= 20000*1e4) {
            curatorEffort[_curator].effortA = curatorEffort[_curator].effortA.add(_effort);
            fullEffortA = fullEffortA.add(_effort);
        }
    }


    function setTransitEfforts(address _curator) public onlyPoolOrInternal returns (bool) {
        curatorEffort[_curator].transitEffortA = curatorEffort[_curator].effortA;
        curatorEffort[_curator].transitEffortB = curatorEffort[_curator].effortB;
        curatorEffort[_curator].transitEffortC = curatorEffort[_curator].effortC;
        curatorEffort[_curator].effortA = 0;
        curatorEffort[_curator].effortB = 0;
        curatorEffort[_curator].effortC = 0;
        return true;
    }

    function setFullEffort() internal {
        transit.fullEffortTransitA = fullEffortA;
        transit.fullEffortTransitB = fullEffortB;
        transit.fullEffortTransitC = fullEffortC;
        fullEffortA = 0;
        fullEffortB = 0;
        fullEffortC = 0;
    }

    function setEfforts(address _curator) external onlyPool returns (bool) {
        curatorEffort[_curator].transitEffortA = 0;
        curatorEffort[_curator].transitEffortB = 0;
        curatorEffort[_curator].transitEffortC = 0;
        curatorEffort[_curator].datePaid = now;
        return true;
    }

    function setRewardPaid(address _curator, uint _rewardPaid) external onlyPool {
        curatorEffort[_curator].rewardPaid = _rewardPaid;
    }

    function getEfforts(address _curator) public view returns (uint, uint, uint) {
        return (
        curatorEffort[_curator].effortA,
        curatorEffort[_curator].effortB,
        curatorEffort[_curator].effortC
        );
    }

    function getTransitEfforts(address _curator) public view returns (uint, uint, uint) {
        return (
        curatorEffort[_curator].transitEffortA,
        curatorEffort[_curator].transitEffortB,
        curatorEffort[_curator].transitEffortC
        );
    }

    function getFullEffort() public view returns (uint, uint, uint) {
        return (
        fullEffortA,
        fullEffortB,
        fullEffortC
        );
    }

    function getFullEffortTransit() public view returns (uint, uint, uint) {
        return (
        transit.fullEffortTransitA,
        transit.fullEffortTransitB,
        transit.fullEffortTransitC
        );
    }

    function getDatePaid(address _curator) external view onlyPool returns (uint) {
        return curatorEffort[_curator].datePaid;
    }

    function getRewardPaid(address _curator) public view returns (uint) {
        return curatorEffort[_curator].rewardPaid;
    }
}
