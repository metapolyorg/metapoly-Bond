pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
contract bD33D is ERC20Upgradeable, OwnableUpgradeable {

    mapping(address => bool) public isAuthorised;

    modifier onlyAuthorised {
        require(isAuthorised[msg.sender], "bD33D: Not Authorised");
        _;
    }

    event AuthorisationUpdated(address indexed account, bool status);

    function initialize(string memory _name, string memory _symbol, address _admin) external initializer {
        __ERC20_init(_name, _symbol);

        __Ownable_init();
        _transferOwnership(_admin);
    }

    function mint(address _to, uint _amount) external onlyAuthorised {
        _mint(_to, _amount);
    }

    function burn(uint _amount) external onlyAuthorised {
        _burn(msg.sender, _amount);
    }

    function setAuthorised(address _account, bool _status) external onlyOwner {
        isAuthorised[_account] = _status;

        emit AuthorisationUpdated(_account, _status);
    }
}