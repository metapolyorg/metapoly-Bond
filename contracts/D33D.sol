// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract D33DImplementation is Initializable, ERC20BurnableUpgradeable, OwnableUpgradeable {
    
    address public treasury;
    bool public feeOn;
    uint public taxPerc; //300 for 3 % (2 decimals)

    mapping(address => bool) isDex;
    mapping(address => bool) isExcluded;

    mapping (address => uint256) private _balances;
    uint256 private _totalSupply;

    bool public isSellTaxed; 
    bool public isBuyTaxed;
    bool public locked;
    address public taxReceiver;

    uint256 private _cap;

    event TreasuryUpdated(address newTreasury);
    event UpdateDex(address dex,bool status);
    event UpdateExcluded(address account,bool status);
    event UpdateTaxReceiver(address receiver);
    event TaxPercUpdated(uint _newPerc);
    
    modifier onlyTreasury {
        require(msg.sender == treasury, "Only Treasury");
        _;
    }

    function initialize(string memory _name, string memory _symbol, uint cap_) external initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        __Ownable_init();

        taxReceiver = treasury;
        _cap = cap_;
        locked = true;
    }

    function setTreasury(address treasury_) external onlyOwner {
        treasury = treasury_;
        emit TreasuryUpdated(treasury_);
    }

    function setTaxPerc(uint _taxPerc) external onlyOwner {
        require(_taxPerc <= 2000, "Not allow over 20%");

        taxPerc = _taxPerc;
        emit TaxPercUpdated(_taxPerc);
    }

    function updateTaxReceiver(address _receiver) external onlyOwner{
        taxReceiver = _receiver;
        emit UpdateTaxReceiver(_receiver);
    }

    function toggleFee(bool _overallFeeStatus, bool _isSellTaxed, bool _isBuyTaxed) external onlyOwner {
        feeOn = _overallFeeStatus;
        isSellTaxed = _isSellTaxed;
        isBuyTaxed = _isBuyTaxed;
    }

    function updateDexAddress(address _dex, bool _status) external onlyOwner {
        isDex[_dex] = _status;

        emit UpdateDex(_dex, _status);
    }

    function updateExcluded(address _account, bool _status) external onlyOwner {
        isExcluded[_account] = _status;

        emit UpdateExcluded(_account, _status);
    }

    function unlock() external onlyOwner {
        locked = false;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function cap() public view returns (uint256) {
        return _cap;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) 
        internal 
        virtual 
        override (ERC20Upgradeable) 
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address _to, uint256 _amount) external onlyTreasury {
        require(totalSupply() + _amount <= cap(), "cap exceeded");
        _mint(_to, _amount);
    }

    function _mint(address account, uint amount) internal override {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint amount) internal override {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }
    
    function _transfer(address sender, address recipient, uint amount) internal override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        //antiSnipe bot
        if(lock == true) {
            require(sender == owner(), "locked" );
        }
        
        uint _amountReceiver = amount;
        uint _totalTax;

        if(feeOn && (isDex[sender] || isDex[recipient]) && !(isExcluded[sender] || isExcluded[recipient])) {
            uint _treasuryTax = amount * taxPerc / 10000;
            require(_treasuryTax > 0, "Not allow zero tax");

            //sell : user -> dex
            //user pays {amount} d33d out of which {taxPerc} percentage is tranferred to treasury
            //remaining to dex
            if(isSellTaxed && isDex[recipient]) {
                _amountReceiver = _amountReceiver - _treasuryTax;
                _totalTax = _totalTax + _treasuryTax ;
            }

            //buy : dex -> user
            //user receives less d33d
            if(isBuyTaxed && isDex[sender]) {
                _amountReceiver = _amountReceiver - _treasuryTax;
                _totalTax = _totalTax + _treasuryTax;
            }
        }
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[sender] = _balances[sender] - amount;
            _balances[taxReceiver] = _balances[taxReceiver] + (_totalTax);
            _balances[recipient] = _balances[recipient] + (_amountReceiver);
        }

        emit Transfer(sender, recipient, amount);
    }

}
