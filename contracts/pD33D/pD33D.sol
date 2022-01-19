// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

// import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20CappedUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract pD33DImplementation is Initializable, ERC20CappedUpgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable {

    function initalize(uint _cap) external initializer {
        __ERC20_init("Pre-D33D", "pD33D");
        __ERC20Capped_init(_cap);
        __Ownable_init();
    }

    function _mint(address account, uint256 amount) internal override(ERC20Upgradeable, ERC20CappedUpgradeable) {
        super._mint(account, amount);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

}