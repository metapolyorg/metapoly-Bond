//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IStakingToken is IERC20Upgradeable{
    function gonsForBalance(uint _amount) external view returns (uint);
    function balanceForGons(uint _amount) external view returns (uint);
    function circulatingSupply() external view returns (uint);
    function index() external view returns (uint);

    function rebase(uint _profit, uint _epoch) external ;
}

interface IStakingWarmUp {
    function retrieve( address _receiver, uint _amount ) external ;
}

interface IDistributor {
    function distribute() external returns (bool);
}

interface IgD33D {
    function mint(address _to, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
    function balanceFrom(uint256 _amount) external view returns (uint256);
    function balanceTo(uint256 _amount) external view returns (uint256);
}

///@dev This contract allows direct deposits from bond
contract StakingBond is Initializable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStakingToken;

    IERC20Upgradeable public D33D;
    IStakingToken public stakingToken;
    IStakingWarmUp public stakingWarmUp;
    IgD33D public gD33D;
    address public distributor;    
    uint public warmupPeriod;
    uint public slashedRewards; // stakingToken collected from 

    bool isLockup;

    struct Claim {
        uint deposit;
        uint gons;
        uint expiry;
        bool lock; // prevents malicious delays
    }
    
    struct Epoch {
        uint length; //epoch length in seconds
        uint number;
        uint timestamp;
        uint distribute;
    }

    struct UserInfo  {
        uint deposit;
        uint gons;
    }

    Epoch public epoch;

    struct Penalty {
        uint interval; //time remaining
        uint perc; //penlty percentage //5000 for 50%
    }
    mapping(uint => Penalty) public penaltyInfo;

    // mapping( address => Claim ) public warmupInfo;
    // mapping(uint => address) public ids;
    
    mapping(address => Claim[]) public ids;
    mapping (address => UserInfo) public userInfo;
    mapping(address => uint) public lastWithdrawnSlot;

    address public DAO;

    address private _trustedForwarder;

    address[] public bonds;
    mapping(address => Claim) public bondDeposits;
    mapping(address => bool) public isBond;
    uint public warmupPeriodBond; //lockup period for direct deposit from bond

    function initialize(address owner_, address _trustedForwarderAddress) external initializer {
        _trustedForwarder = _trustedForwarderAddress;
        __Ownable_init();
        transferOwnership(owner_); //transfer ownership from proxyAdmin contract to deployer
    }

    function initialzeStaking(IERC20Upgradeable _D33D, IStakingToken _sD33D, address distributor_, address _stakingWarmUp, 
        uint _epochLength, uint _firstEpochNumber,
        uint _firstEpochTimestamp, uint warmUpPeriod_, bool _isLockup, address _DAO, address _gD33D) external onlyOwner {

        require(address(D33D) == address(0), "Already initalized");

        D33D = _D33D;
        stakingToken = _sD33D;
        distributor = distributor_;
        warmupPeriod = warmUpPeriod_;
        DAO = _DAO;
        gD33D = IgD33D(_gD33D);

        epoch = Epoch({
            length: _epochLength,
            number: _firstEpochNumber,
            timestamp: _firstEpochTimestamp + _epochLength,
            distribute: 0
        });

        isLockup = _isLockup;

        stakingWarmUp = IStakingWarmUp(_stakingWarmUp);
        
    }
    ///@notice Function to  deposit D33D. stakingToken will not be trensferred in this function.
    function stake(uint _amount, address _receiver) external returns (bool) {
        rebase();
        D33D.safeTransferFrom(_msgSender(), address(this), _amount);

        UserInfo memory info = userInfo[ _receiver ];
        // require( !info.lock, "Deposits for account are locked" );

        ids[_receiver].push(Claim({
            deposit:  _amount ,
            gons: stakingToken.gonsForBalance( _amount ),
            expiry: epoch.timestamp +  warmupPeriod,
            lock: false
        }));

        userInfo[ _receiver ] = UserInfo ({
            deposit: info.deposit +  _amount ,
            gons: info.gons + stakingToken.gonsForBalance( _amount )
        });

        stakingToken.transfer(address(stakingWarmUp), _amount);
        return true;

    }

    function bondStake(uint _amount, address _receiver) external returns (bool) {
        require(isBond[msg.sender], "Staking: Only Bond" );
        rebase();

        D33D.safeTransferFrom(msg.sender, address(this), _amount);

        Claim memory info = bondDeposits[_receiver];
        bondDeposits[_receiver] = Claim({
            deposit: info.deposit +  _amount ,
            gons: info.gons + stakingToken.gonsForBalance( _amount ),
            expiry: epoch.timestamp +  warmupPeriodBond,
            lock: false
        });

        stakingToken.transfer(address(stakingWarmUp), _amount);
        return true;

    }

    ///@dev To retrieve gD33D deposited directly from bond
    function bondClaim() external {
        address _sender = _msgSender();
        Claim memory info = bondDeposits[_sender];

        
        if ( epoch.timestamp >= info.expiry && info.expiry != 0) { 
            delete bondDeposits[_sender];
            uint amount = stakingToken.balanceForGons(info.gons);
            
            stakingWarmUp.retrieve(_sender, amount);
            _wrap(amount, _sender);
        }
    }

    ///@notice Claims only the expired deposits
    function safeClaim() public {
        address _sender = _msgSender();
        uint totalDeposits = ids[_sender].length;
        require(totalDeposits > 0, "No previous deposits");

        uint _lastWithdrawnSlot = lastWithdrawnSlot[_sender];

        uint _currentSlot;
        //totalDeposits is length of array, so greater than 1 == more than 1 deposit (else block)
        //set current slot to 0 if there is only one deposit
        //else set current slot to next available slot 
        if(totalDeposits == 1) {
            Claim memory info = ids[_sender][_currentSlot];
            require(info.deposit > 0, "No New deposits"); //slot 0 is already withdrawn if info.deposit is 0
            //currentSlot is 0
        } else {
            require(_lastWithdrawnSlot < totalDeposits - 1, "No New Deposits");
            _currentSlot = _lastWithdrawnSlot +1;
        }

        uint _amount;
        uint _depositedAmt; //for easy querying
        
        uint targetSlot = totalDeposits > _lastWithdrawnSlot + 10 //if more than 10 deposits after last withdrawl
        ? _lastWithdrawnSlot + 10 //check only next 10 slots
        : totalDeposits; //if less than 10 new deposits, check upto totalDeposits(i.e totalDeposits -1 th slot)
        
        for(; _currentSlot < targetSlot; _currentSlot++) {
            Claim memory info = ids[_sender][_currentSlot];
            
            if(epoch.timestamp >= info.expiry && info.expiry != 0) {
                _amount += stakingToken.balanceForGons(info.gons);
                _depositedAmt += info.deposit;
                delete ids[_sender][_currentSlot]; //gas refund
            } else {
                //withdrawn upto previous loop's slot
                //This block is reached only once

                //if no deposits _currentSlot is 0, set lastWithdrawnSlot = 0 else set previous slot
                lastWithdrawnSlot[_sender] = _currentSlot == 0 ? 0 : _currentSlot -1;
                _currentSlot = targetSlot; //exit loop
            }

        }

        if(_amount > 0) {
            UserInfo memory _userInfo = userInfo[ _sender ];
            
            userInfo[ _sender ] = UserInfo ({
                deposit: _userInfo.deposit - _depositedAmt ,
                gons: _userInfo.gons - stakingToken.gonsForBalance( _userInfo.deposit - _depositedAmt )
            });
            
            stakingWarmUp.retrieve(address(this), _amount);
            _wrap(_amount, _sender);

        }
    }

    function forceClaim() public {
        address _sender = _msgSender();
        require(isLockup == false, "Cannot withdraw during lockup period"); //true for lockedStaking

        uint totalDeposits = ids[_sender].length;
        require(totalDeposits > 0, "No previous deposits");

        uint _lastWithdrawnSlot = lastWithdrawnSlot[_sender];
        uint _currentSlot;
        //totalDeposits is length of array, so greater than 1 == more than 1 deposit (else block)
        //set current slot to 0 if there is only one deposit
        //else set current slot to next available slot 
        if(totalDeposits == 1) {
            Claim memory info = ids[_sender][_currentSlot];
            require(info.deposit > 0, "No New deposits"); //slot 0 is already withdrawn if info.deposit is 0
            //currentSlot is 0
        } else {
            require(_lastWithdrawnSlot < totalDeposits - 1, "No New Deposits");

            if(_lastWithdrawnSlot == 0 && ids[_sender][0].deposit > 0) {
                //slot 0 is not withdrawn yet
                _currentSlot = 0;
            } else {
                _currentSlot = _lastWithdrawnSlot +1;
            }
        }

        uint _amount;
        uint _reward;
        uint _depositedAmt;
        uint _penalty;

        uint targetSlot = totalDeposits > _lastWithdrawnSlot + 10 //if more than 10 deposits after last withdrawl
            ? _lastWithdrawnSlot + 10 //check only next 10 slots
            : totalDeposits; //if less than 10 new deposits, check upto totalDeposits(i.e totalDeposits -1 th slot)
                
        for(; _currentSlot < targetSlot; _currentSlot++) {
            Claim memory info = ids[_sender][_currentSlot];


            uint _amtCurrSlot = stakingToken.balanceForGons(info.gons);
            uint _rewardCurrSlot = _amtCurrSlot - info.deposit;
            _reward += _rewardCurrSlot;
            _amount += _amtCurrSlot;
            _depositedAmt += info.deposit;
            
            if(info.expiry > epoch.timestamp) {
                _penalty += _calculatePenalty(_rewardCurrSlot, info.expiry);
            }
            
            delete ids[_sender][_currentSlot]; //gas refund
        }

        lastWithdrawnSlot[_sender] = targetSlot -1; //targetSlot is length so subtracting 1

        uint amtToWithdraw;
        
        stakingWarmUp.retrieve(address(this), _amount);

        if(_penalty > 0) {
            amtToWithdraw = _amount - _penalty;
            _wrap(_penalty, DAO);
        } else {
            amtToWithdraw = _amount;
        }

        UserInfo memory _userInfo = userInfo[ _sender ];
            
        userInfo[ _sender ] = UserInfo ({
            deposit: _userInfo.deposit - _depositedAmt ,
            gons: _userInfo.gons - stakingToken.gonsForBalance( _userInfo.deposit - _depositedAmt )
        });

        _wrap(amtToWithdraw, _sender);
    }

    function unStake(uint _amount, bool _trigger) external {
        if(_trigger == true) {
            rebase();
        }

        address _sender = _msgSender();
        
        uint _amt = _unWrap(_amount, _sender);
        D33D.safeTransfer( _sender, _amt );
    }

    ///@return gBalance_ _amount equivalent gD33D 
    function _wrap(uint _amount, address _to) internal returns (uint gBalance_) {
        //should transfer sD33D to this contract before calling this function
        gBalance_ = gD33D.balanceTo(_amount);
        gD33D.mint(_to, gBalance_);
    }

    ///@param _amount number of gD33D to upwrap to sD33D
    ///@return sBalance _amount equivalent sD33D 
    function _unWrap(uint _amount, address _user) internal returns(uint sBalance) {
        gD33D.burn(_user, _amount);
        sBalance = gD33D.balanceFrom(_amount);

        //transfer out sD33D or D33D after this function
    }

    function _calculatePenalty(uint _reward, uint _expiry) public view returns (uint) {
        uint diff = _expiry - epoch.timestamp; //lock time remaining

        if(diff >= penaltyInfo[0].interval) { //max Interval (max fee).
            return _reward * penaltyInfo[0].perc / 100_00;

        } else if(diff >= penaltyInfo[1].interval) {
            return _reward * penaltyInfo[1].perc / 100_00;

        } else if(diff >= penaltyInfo[2].interval) {
            return _reward * penaltyInfo[2].perc / 100_00;

        } else if(diff >= penaltyInfo[3].interval) { //least interval (least fee). Interval 
            return _reward * penaltyInfo[3].perc / 100_00;
        } else {
            return _reward * penaltyInfo[4].perc / 100_00;

        }
    }

    ///@return rewards_ Total rewards without penalty deductions (in D33D terms)
    ///@return penalty_ Penalty amount (in D33D terms)
    ///@return withdrawn_ gD33D that will be withdrawn (in gD33D)
    function forceClaimInfo(address _user) external view returns (uint rewards_, uint penalty_, uint withdrawn_){
        uint totalDeposits = ids[_user].length;

        if(totalDeposits > 0) {
            uint _lastWithdrawnSlot = lastWithdrawnSlot[_user];
            uint _currentSlot;

            if(_lastWithdrawnSlot == 0 && ids[_user][0].deposit > 0) {
                //slot 0 is not withdrawn yet
                _currentSlot = 0;
            } else {
                _currentSlot = _lastWithdrawnSlot +1;
            }

            uint targetSlot = totalDeposits > _lastWithdrawnSlot + 10 //if more than 10 deposits after last withdrawl
            ? _lastWithdrawnSlot + 10 //check only next 10 slots
            : totalDeposits; //if less than 10 new deposits, check upto totalDeposits(i.e totalDeposits -1 th slot)
                
            uint _amount;
            for(; _currentSlot < targetSlot; _currentSlot++) {
                Claim memory info = ids[_user][_currentSlot];


                uint _amtCurrSlot = stakingToken.balanceForGons(info.gons);
                uint _rewardCurrSlot = _amtCurrSlot - info.deposit;
                rewards_ += _rewardCurrSlot;
                _amount += _amtCurrSlot;
            
                if(info.expiry > epoch.timestamp) {
                    penalty_ += _calculatePenalty(_rewardCurrSlot, info.expiry);
                }
            
            }

            withdrawn_ = gD33D.balanceTo(_amount - penalty_);

        }
        
    }

    function safeClaimInfo(address _user) external view returns (uint rewards_, uint withdrawn_) {
        uint totalDeposits = ids[_user].length;

        if(totalDeposits > 0) {
            uint _lastWithdrawnSlot = lastWithdrawnSlot[_user];
            uint _currentSlot;

            if(_lastWithdrawnSlot == 0 && ids[_user][0].deposit > 0) {
                //slot 0 is not withdrawn yet
                _currentSlot = 0;
            } else {
                _currentSlot = _lastWithdrawnSlot +1;
            }

            uint targetSlot = totalDeposits > _lastWithdrawnSlot + 10 //if more than 10 deposits after last withdrawl
            ? _lastWithdrawnSlot + 10 //check only next 10 slots
            : totalDeposits; //if less than 10 new deposits, check upto totalDeposits(i.e totalDeposits -1 th slot)
                
            uint _amount;
            for(; _currentSlot < targetSlot; _currentSlot++) {
                Claim memory info = ids[_user][_currentSlot];

                if(epoch.timestamp >= info.expiry && info.expiry != 0) {
                    uint _amtCurrSlot = stakingToken.balanceForGons(info.gons);
                    _amount += _amtCurrSlot;
                    uint _rewardCurrSlot = _amtCurrSlot - info.deposit;
                    rewards_ += _rewardCurrSlot;
                } else {
                    //This block is reached only once

                    _currentSlot = targetSlot; //exit loop
                }
            
            }

            withdrawn_ = gD33D.balanceTo(_amount);

        }
    }

    function idInfo(address _user) external view returns (uint first_, uint end_) {
        uint _lastWithdrawnSlot  = lastWithdrawnSlot[_user];
        
        first_ = _lastWithdrawnSlot == 0 && ids[_user][0].deposit > 0 
        ? 0  
        : _lastWithdrawnSlot +1;

        end_ = ids[_user].length > 0 ? ids[_user].length -1 : 0;
    }

    ///@return deposited amount
    ///@return principle + rewards from this deposit
    ///@return Lockup end time
    function depositInfo(address _user, uint _id) external view returns (uint, uint, uint) {
        if(ids[_user].length > 0) {
            Claim memory info = ids[_user][_id];
            return (
                info.deposit, 
                stakingToken.balanceForGons( info.gons ),
                info.expiry
            );
        }
    }

    function setPenaltyInfo(uint _id, uint _interval, uint _feePerc) external onlyOwner{
        penaltyInfo[_id] = Penalty({
            interval: _interval,
            perc: _feePerc
        });
    }

    function rebase() public {
        if(epoch.timestamp <= block.timestamp) {
            stakingToken.rebase(epoch.distribute, epoch.number);

            // epoch.endBlock = epoch.endBlock + epoch.length;
            epoch.timestamp = epoch.timestamp + epoch.length;

            epoch.number++;

            if ( distributor != address(0) ) {
                IDistributor( distributor ).distribute();
            }

            uint balance = D33D.balanceOf(address(this));
            uint staked = stakingToken.circulatingSupply();

            if( balance <= staked ) {
                epoch.distribute = 0;
            } else {
                epoch.distribute = balance -  staked;
            }
        }
    }

    function index() public view returns ( uint ) {
        return stakingToken.index();
    }

    function trustedForwarder() public view returns (address){
        return _trustedForwarder;
    }

    function setTrustedForwarder(address _forwarder) external onlyOwner {
        _trustedForwarder = _forwarder;
    }

    function isTrustedForwarder(address forwarder) public view returns(bool) {
        return forwarder == _trustedForwarder;
    }

    /**
     * return the sender of this call.
     * if the call came through our trusted forwarder, return the original sender.
     * otherwise, return `msg.sender`.
     * should be used in the contract anywhere instead of msg.sender
     */
    function _msgSender() internal override view returns (address ret) {
        if (msg.data.length >= 20 && isTrustedForwarder(msg.sender)) {
            // At this point we know that the sender is a trusted forwarder,
            // so we trust that the last bytes of msg.data are the verified sender address.
            // extract sender address from the end of msg.data
            assembly {
                ret := shr(96,calldataload(sub(calldatasize(),20)))
            }
        } else {
            ret = msg.sender;
        }
    }
    function versionRecipient() external view returns (string memory) {
        return "1";
    }

    function setWarmupPeriodBond(uint _warmupPeriod) external onlyOwner {
        warmupPeriodBond = _warmupPeriod;
    }

    function updateBondAddress(address _bond, bool _status) external onlyOwner {
        isBond[_bond] = _status;
        if(_status) {
            bonds.push(_bond);
        }
    }


}
