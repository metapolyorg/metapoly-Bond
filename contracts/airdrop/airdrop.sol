
//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

contract Airdrop is Initializable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public D33D;
    address public feeReceiver;
    address public signer;

    struct User {
        uint level; //starts from 1 (not index)
        bool unlocked;
        bool claimed;
    }

    struct LevelInfo {
        uint fee; //fee paid by user for the level
        uint rewardPerc; //Reward from the referred user //2 decimals 100 for 1%
    }

    mapping(address => User) public users;
    mapping(uint => LevelInfo) public levelInfos; //starts from 0. Level one info is at index 0

    function initialize(address _d33d, address _feeReceiver, address _signer, 
        uint[] memory _fee, uint[] memory _rewardPerc) external initializer {
        D33D = _d33d;
        feeReceiver = _feeReceiver;
        signer = _signer;

        for(uint i =0; i <_fee.length; i++) {
            LevelInfo memory info = LevelInfo({
                fee: _fee[i],
                rewardPerc: _rewardPerc[i]
            });

            levelInfos[i] = info;
        }

        __Ownable_init();
    }

    function unlock(address _account, address payable _referrer) external payable {
        LevelInfo memory info = levelInfos[0]; //get level 1 info
        require(msg.value == info.fee, "Invalid fee");
        require(users[_account].unlocked == false, "Already unlocked");
        require(_account != _referrer);

        users[_account].unlocked = true;
        users[_account].level = 1; //activate first level

        uint _reward;        
        if(_referrer != address(0)) {
            uint level = users[_referrer].level -1;

            _reward = info.fee * levelInfos[level].rewardPerc / 10000;
            (bool _status, ) = _referrer.call{value: _reward}("");
            require(_status,"reward transfer failed");
        }

        uint _remaining = info.fee - _reward;

        (bool _status, ) = feeReceiver.call{value: _remaining}("");
        require(_status,"fee transfer failed");
    }

    function claim(bytes calldata _signature, uint _amount) external {
        require(users[msg.sender].unlocked, "Not unlocked");
        require(users[msg.sender].claimed == false ,"already claimed");

        bytes32 message = keccak256(abi.encodePacked(msg.sender, _amount));
        bytes32 messageHash = ECDSAUpgradeable.toEthSignedMessageHash(message);
        address recoveredAddr = ECDSAUpgradeable.recover(messageHash, _signature);
        require(recoveredAddr == signer, "Invalid signature");

        IERC20Upgradeable(D33D).safeTransfer(msg.sender, _amount);
    }

    function upgrade(uint _toLevel) external payable{
        uint _fee = getUpgradeCost(msg.sender, _toLevel);
        require(msg.value == _fee, "Invalid fee");

        User memory userInfo = users[msg.sender];
        require(userInfo.unlocked, "Not unlocked");
        require(userInfo.level < _toLevel, "Already active");

        users[msg.sender].level = _toLevel;
    }

    ///@param _toLevel Actual level to upgrade (not index)
    function getUpgradeCost(address _user, uint _toLevel) public view returns (uint fee_) {

        require(_toLevel < 4, "Invalid Level"); //upto 3 levels

        uint currentLevel = users[_user].level;

        for(uint i = currentLevel; i <_toLevel ; i++) {
            fee_ += levelInfos[i].fee; //level 1 fee is at index 0
        }
        
    }

    ///@param _level Level. For level 1 in initial fee 
    ///@param _rewardPerc Percentage of fee sent as rewards to referrer
    ///@param _fee Fee to upgrade level
    function setLevelInfo(uint _level, uint _rewardPerc, uint _fee) external onlyOwner {
        require(_level < 4, "Invalid Level"); //upto 3 levels

        LevelInfo memory info = LevelInfo({
            fee: _fee,
            rewardPerc: _rewardPerc
        });
        
        levelInfos[_level -1] = info;
    }

}