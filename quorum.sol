pragma solidity 0.4.21;

import '../contracts/misc/SafeMath.sol';
import '../contracts/misc/Ownable.sol';

contract Quorum is Ownable {

    using SafeMath for *;

    address public proposalContract;

    function Quorum() public {
        owner = msg.sender;
    }

    function setProposalContract(address _proposalContract) public onlyOwner {
        proposalContract = _proposalContract;
    }

    modifier onlyProposalContract() {
        require(msg.sender == proposalContract);
        _;
    }

    function checkCitizenQuorum(uint _upVotes, uint _downVotes) external view onlyProposalContract returns(bool) {
        uint allVotes = _upVotes.add(_downVotes);
        if ( allVotes == 0 ) {
            return false;
        }
        uint citizensQuorum = uint(_upVotes).mul(uint(100)).div(uint(allVotes));
        if (citizensQuorum >= 60) {
            return true;
        } else {
            return false;
        }
    }

    function checkCuratorsQuorum(uint _upTicks, uint _downTicks) external view onlyProposalContract returns(bool) {
        uint allTicks = _upTicks.add(_downTicks);
        if ( allTicks == 0 ) {
            return false;
        }
        uint curatorsQuorum = uint(_upTicks).mul(uint(100)).div(uint(allTicks));
        if (curatorsQuorum >= 70) {
            return true;
        } else {
            return false;
        }
    }
}
