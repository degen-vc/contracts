pragma solidity 0.4.21;

contract Oracle {
    uint private price;
    address private trustedAddress;

    event Update();

    function Oracle() public {
        trustedAddress = msg.sender;
    }

    modifier onlyTrustedAddress() {
        require(msg.sender == trustedAddress);
        _;
    }

    function start() public onlyTrustedAddress {
        emit Update();
    }

    function updatePrice(uint _newPrice) public onlyTrustedAddress {
        price = _newPrice;
    }

    function getPrice() external view returns(uint) {
        return price;
    }

    function updateTrustedAddress(address _newAddress) public onlyTrustedAddress {
        require(_newAddress != address(0));
        trustedAddress = _newAddress;
    }
}
