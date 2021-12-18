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

contract Staking is Initializable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStakingToken;

    IERC20Upgradeable public D33D;
    IStakingToken public stakingToken;
    IStakingWarmUp public stakingWarmUp;

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
    Epoch public epoch;

    mapping( address => Claim ) public warmupInfo;

    address public DAO;

    function initialize(address owner_) external initializer {
        __Ownable_init();
        transferOwnership(owner_); //transfer ownership from proxyAdmin contract to deployer
    }

    function initialzeStaking(IERC20Upgradeable _D33D, IStakingToken _sD33D, address distributor_, address _stakingWarmUp, 
        uint _epochLength, uint _firstEpochNumber,
        uint _firstEpochTimestamp, uint warmUpPeriod_, bool _isLockup, address _DAO) external onlyOwner {

        require(address(D33D) == address(0), "Already initalized");

        D33D = _D33D;
        stakingToken = _sD33D;
        distributor = distributor_;
        warmupPeriod = warmUpPeriod_;
        DAO = _DAO;
    
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

        D33D.safeTransferFrom(msg.sender, address(this), _amount);

        Claim memory info = warmupInfo[ _receiver ];
        require( !info.lock, "Deposits for account are locked" );

        warmupInfo[ _receiver ] = Claim ({
            deposit: info.deposit +  _amount ,
            gons: info.gons + stakingToken.gonsForBalance( _amount ),
            expiry: epoch.timestamp +  warmupPeriod,
            lock: false
        });

        stakingToken.transfer(address(stakingWarmUp), _amount);
        return true;

    }

    ///@dev Releases stakingToken after the minimum lockup period
    function claim() public {
        Claim memory info = warmupInfo[msg.sender];

        
        if ( epoch.timestamp >= info.expiry && info.expiry != 0) { 
            delete warmupInfo[msg.sender];
            uint amount = stakingToken.balanceForGons(info.gons);
            
            stakingWarmUp.retrieve(msg.sender, amount);
        }
    }

    function claimRewards(address _receiver) external {
        require(isLockup == true, "can claim rewards only in locked staking");
        Claim memory info = warmupInfo[_receiver];
        //difference in deposited amount and current sTOKEN amount are the rewards
        uint _amount = stakingToken.balanceForGons( info.gons );
        uint rewards = _amount - info.deposit;
        stakingWarmUp.retrieve(address(this), rewards);

        warmupInfo[_receiver].gons = stakingToken.gonsForBalance( info.deposit );
        warmupInfo[_receiver].expiry = epoch.timestamp +  warmupPeriod; //resets lockup period

        D33D.safeTransfer(_receiver, rewards);
    }

    ///@notice Function to withdraw the staked D33D before lockup period. Penalty amount is subtracted from rewards
    function forfeit() external {
        require(isLockup == false, "Cannot withdraw during lockup period"); //true for lockedStaking
        Claim memory info = warmupInfo[ msg.sender ];
        delete warmupInfo[ msg.sender ];

        uint _amount = stakingToken.balanceForGons( info.gons );
        stakingWarmUp.retrieve(address(this), _amount);
        uint reward = _amount - info.deposit;

        uint amtToWithdraw;

        if(reward > 0) {
            //50% of rewards as penalty
            uint penalty = reward * 5000 / 10000; 
            reward = reward - penalty;
            amtToWithdraw = info.deposit + reward;

            //transfer penalty to distributor
            stakingToken.transfer(DAO, penalty);

        } else {
            amtToWithdraw = info.deposit;
        }

        D33D.safeTransfer( msg.sender, amtToWithdraw );        
    }

    function unStake(uint _amount, bool _trigger) external {
        if(_trigger == true) {
            rebase();
        }
    
        stakingToken.safeTransferFrom( msg.sender, address(this), _amount );
        D33D.safeTransfer( msg.sender, _amount );
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

    function toggleDepositLock() external {
        warmupInfo[ msg.sender ].lock = !warmupInfo[ msg.sender ].lock;
    }


    function index() public view returns ( uint ) {
        return stakingToken.index();
    }


}
