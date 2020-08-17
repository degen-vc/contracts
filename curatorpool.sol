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
    }


    // calculate and withdraw rewarding which was gained by curator. Able to get it by clicking button
    function curatorReward() public {
        require(curatorContract.checkExistence(msg.sender));
        uint date;
        uint rewarding;
        if (now <= timestamp.add(1 days)) {
            date = curatorRewardingContract.getDatePaid(msg.sender);
            if (date < timestamp.add(1 days) || date == 0) {
                require(curatorRewardingContract.setTransitEfforts(msg.sender));

                rewarding = getRewarding(msg.sender);
                require(rewarding != 0);
                require(curatorRewardingContract.setEfforts(msg.sender));
                msg.sender.transfer(rewarding);
                curatorRewardingContract.setRewardPaid(msg.sender, rewarding);
            } else {
                revert();
            }

        } else if (now > timestamp.add(1 days)) {
            curatorRewardingContract.calcEffort(0, msg.sender);
            rewarding = getRewarding(msg.sender);
            require(rewarding != 0);
            require(curatorRewardingContract.setEfforts(msg.sender));
            msg.sender.transfer(rewarding);
            curatorRewardingContract.setRewardPaid(msg.sender, rewarding);
        }
    }

    function getRewarding(address _curator) internal view returns (uint) {
        uint effortA;
        uint effortB;
        uint effortC;
        (effortA, effortB, effortC) =  curatorRewardingContract.getTransitEfforts(_curator);
        return (effortA * oneEffortA).add(effortB * oneEffortB).add(effortC * oneEffortC);
    }

    function calculateGroups() external {
        rewardingPoolA = (transit.balance.mul(60).div(100));
        rewardingPoolB = (transit.balance.mul(30).div(100));
        rewardingPoolC = (transit.balance.mul(10).div(100));
    }

    function calculateOneEffort(uint fullEffortTransitA, uint fullEffortTransitB, uint fullEffortTransitC) external {
        if (fullEffortTransitA != 0) {
            oneEffortA = rewardingPoolA.div(fullEffortTransitA);
        } else {
            oneEffortA = 0;
        }
        if (fullEffortTransitB != 0) {
            oneEffortB = rewardingPoolB.div(fullEffortTransitB);
        } else {
            oneEffortB = 0;
        }
        if (fullEffortTransitC != 0) {
            oneEffortC = rewardingPoolC.div(fullEffortTransitC);
        } else {
            oneEffortC = 0;
        }
    }

    function getTimestamp() external view returns(uint) {
        return timestamp;
    }

    function () public payable {}

    function getBalance () public view returns (uint) {
        return transit.balance;
    }

}
