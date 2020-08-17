pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

contract CuratorAddress {
    function getFullReputation() public view returns (uint);
}

contract Reputation is Ownable {

    using SafeMath for *;

    uint fullReputation;
    uint public groupA;
    uint public groupB;
    uint public groupC;
    uint activationQuorumUptick; //if proposal was activated, reached the quorum and curator uptick this proposal
    uint noActivationNoQuorumDowntick; //if proposal was not activated, not reached the quorum and curator downtick this proposal
    uint activationNoQuorumDowntick; //if proposal was activated, not reached the quorum and curator downtick this proposal
    uint activationNoQuorumUptick; //if proposal was activated, not reached the quorum and curator uptick this proposal
    uint noActivationNoQuorumUptick; //if proposal was not activated,not reached the quorum and curator uptick this proposal
    uint activationQuorumDowntick;


    CuratorAddress curatorContract;
    address public curatorAddress;

    function Reputation() public {
        activationQuorumUptick = 7;
        noActivationNoQuorumDowntick = 2;
        activationNoQuorumDowntick = 7;
        activationNoQuorumUptick = 5;
        noActivationNoQuorumUptick = 2;
        activationQuorumDowntick = 5;
        owner = msg.sender;

        groupA = 5;
        groupB = 7;
        groupC = 9;
    }
    // set curator contract address
    function setCuratorContractAddress(address _curatorContract) public onlyOwner {
        require(_curatorContract != address(0));
        curatorContract = CuratorAddress(_curatorContract);
        curatorAddress = _curatorContract;
    }

//    function setFoundationAddresses(address _foundation) public onlyOwner {
//        require(_foundation != address(0));
//        foundation = _foundation;
//    }
//
//    //only Foundation can call some functions
//    modifier onlyFoundation() {
//        require(msg.sender == foundation);
//        _;
//    }
//
    // only Curator contract can call some functions
    modifier onlyCurator() {
        require(msg.sender == curatorAddress);
        _;
    }

    function calculateRep(uint fullPlatformReputation, uint curatorReputation, bool _activation, bool _quorum, bool _uptick, bool _downtick, bool _flag)
    external view onlyCurator returns (uint, uint8, uint) {
            uint curatorRep;
            uint fullRep;
            uint8 groupRep;
                if (_activation && _quorum && _uptick && !_downtick && !_flag) {
                    curatorRep = curatorReputation + activationQuorumUptick;
                    fullRep = fullPlatformReputation + activationQuorumUptick;
                    groupRep = getGroupRate(curatorRep);
                    return (curatorRep, groupRep, fullRep);
                }
                if (!_activation && !_quorum && !_uptick && (_downtick || _flag)) {
                    curatorRep = curatorReputation + noActivationNoQuorumDowntick;
                    fullRep = fullPlatformReputation + noActivationNoQuorumDowntick;
                    groupRep = getGroupRate(curatorRep);
                    return (curatorRep, groupRep, fullRep);
                }
                if (_activation && !_quorum && !_uptick && (_downtick || _flag)) {
                    curatorRep = curatorReputation + activationNoQuorumDowntick;
                    fullRep = fullPlatformReputation + activationNoQuorumDowntick;
                    groupRep = getGroupRate(curatorRep);
                    return (curatorRep, groupRep, fullRep);
                }
                else {
                    return calculateReputationNegative(fullPlatformReputation,curatorReputation, _activation, _quorum, _uptick, _downtick, _flag);
                }
    }

    function calculateReputationNegative(uint fullPlatformReputation, uint curatorReputation,  bool _activation, bool _quorum, bool _uptick, bool _downtick, bool _flag)
    internal view returns (uint, uint8, uint)  {
        uint curatorRep;
        uint fullRep;
        uint8 groupRep;
            if (!_activation && !_quorum  && _uptick && (!_downtick || !_flag)) {
                if (curatorReputation <= noActivationNoQuorumUptick) {
                    fullRep = fullPlatformReputation - curatorReputation;
                    curatorRep = 0;
                } else {
                    curatorRep = curatorReputation - noActivationNoQuorumUptick;
                    fullRep = fullPlatformReputation - noActivationNoQuorumUptick;
                }
                groupRep = getGroupRate(curatorRep);
                return (curatorRep, groupRep, fullRep);
            }
            if (_activation && !_quorum && _uptick && (!_downtick  || !_flag)) {
                if (curatorReputation <= activationNoQuorumUptick) {
                    fullRep = fullPlatformReputation - curatorReputation;
                    curatorRep = 0;
                } else {
                    curatorRep = curatorReputation - activationNoQuorumUptick;
                    fullRep = fullPlatformReputation - activationNoQuorumUptick;
                }
                groupRep = getGroupRate(curatorRep);
                return (curatorRep, groupRep, fullRep);
            }
            if (_activation && _quorum && !_uptick && (_downtick || _flag )) {
                if (curatorReputation <= activationQuorumDowntick) {
                    fullRep = fullPlatformReputation - curatorReputation;
                    curatorRep = 0;
                } else {
                    curatorRep = curatorReputation - activationQuorumDowntick;
                    fullRep = fullPlatformReputation - activationQuorumDowntick;
                }
                groupRep = getGroupRate(curatorRep);
                return (curatorRep, groupRep, fullRep);
            }
    }

    //groupA = 1, bottom 5%
    //groupB = 2
    //groupC = 3
    //groupD = 4
    //will be triggered by foundation by clicking button to calculate groups rate according to the reputation
    //'fullReputation' - reputation of all curators on the platform. Getting from the Curator contract
    function calculateRates() public  {
        fullReputation = curatorContract.getFullReputation();
        groupA = (fullReputation.mul(5)).div(100);
        groupB = (fullReputation.mul(35)).div(100);
        groupC = (fullReputation.mul(80)).div(100);
    }

//    //method is calling by Curator contract after each reputation calculation for curator and assign for curator
//    //new reputation group according to the new reputation score
    function getGroupRate(uint _reputation) public view onlyCurator returns (uint8) {
        if (_reputation <= groupA) {
            return 1;
        } if (_reputation > groupA && _reputation <= groupB) {
             return 2;
        } if (_reputation > groupB && _reputation <= groupC) {
          return 3;
        } if (_reputation > groupC) {
          return 4;
        }
    }

}
