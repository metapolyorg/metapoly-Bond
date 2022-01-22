// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract pD33D is Initializable, OwnableUpgradeable, ERC20BurnableUpgradeable {

    address public pD33DRedeemer;

    function initialize(uint _supply) external initializer {
        __ERC20_init("Pre-D33D", "pD33D");
        __Ownable_init();

        _mint(msg.sender, _supply);
    }

    function burnFrom(address account, uint256 amount) public override {
        require(msg.sender == pD33DRedeemer, "Only redeemer");

        _burn(account, amount);
    }

    function setRedeemer(address _pD33DRedeemer) external onlyOwner {
        pD33DRedeemer = _pD33DRedeemer;
    }
}