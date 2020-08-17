pragma solidity 0.4.21;

import '../contracts/misc/Ownable.sol';

contract Limits is Ownable {

    address public curatorAddress;

    function Limits() public {
        owner = msg.sender;
    }

    function setCuratorContractAddress(address _curatorContract) public onlyOwner {
        require(_curatorContract != address(0));
        curatorAddress = _curatorContract;
    }

    // only Curator contract can call some functions
    modifier onlyCurator() {
        require(msg.sender == curatorAddress);
        _;
    }

    function checkUpdateLimits(uint _limit) external view onlyCurator returns (bool, uint) {
        uint setLimit;
        setLimit = _limit;
        if (setLimit > 0) {
            setLimit -= 1;
            return (true, setLimit);
        } else {
            return (false, setLimit);
        }
    }

//        groupA = 1
//        groupB = 2
//        groupC = 3
//        groupD = 4
//        update curator's limits if 24 hours is passed

    function setLimits(uint8 _repGroup, uint256 dgvcBalance) external view onlyCurator returns (uint, uint, uint, uint) {
        uint like;
        uint flag;
        uint comment;
        uint likeComment;

        (like, flag, comment, likeComment) = limitsOfToken(dgvcBalance, _repGroup);
        return (like, flag, comment, likeComment);
    }

    function limitsOfToken(uint dgvcBalance, uint8 _repGroup) internal pure returns (uint, uint, uint, uint) {
        if (_repGroup == 1) {
            if (dgvcBalance >= 1000*1e4 && dgvcBalance < 2000*1e4) {
                return (20, 1, 1, 10);
            } else if (dgvcBalance >= 2000*1e4 && dgvcBalance < 10000*1e4) {
                return (20, 3, 4, 10);
            } else if (dgvcBalance >= 10000*1e4) {
                return (30, 5, 5, 1000);
            } else if(dgvcBalance <= 4*1e4)
                return (0, 0, 0, 0);
            else {
                return (30, 0, 0, 0);
            }
        } else if (_repGroup == 2) {
            if ( dgvcBalance >= 1000*1e4 && dgvcBalance < 2000*1e4) {
                return (20, 1, 1, 10);
            } else if (dgvcBalance >= 2000*1e4 && dgvcBalance < 10000*1e4) {
                return (20, 3, 4, 10);
            } else if (dgvcBalance >= 10000*1e4) {
                return (30, 5, 5, 1000);
            } else if (dgvcBalance < 1000*1e4) {
                return (20, 1, 1, 10);
            }
        }
        else if (_repGroup == 3) {
            if (dgvcBalance >= 2000*1e4 && dgvcBalance < 10000*1e4) {
                return (20, 3, 4, 10);
            } else if (dgvcBalance >= 10000*1e4) {
                return (30, 5, 5, 1000);
            } else if (dgvcBalance < 2000*1e4) {
                return (20, 3, 4, 10);
            }
        }
        else if (_repGroup == 4*1e4) {
            return (30, 5, 5, 1000);
        }
    }
}
