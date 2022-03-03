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

interface IUSMMinter {
    function mintWithD33d(uint _d33dAmount, address _to) external returns(uint _usmAmount);
}

contract Staking is Initializable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IStakingToken;

    IERC20Upgradeable public D33D;
    // IERC20Upgradeable public constant USM = "" //TODO uncomment;
    IStakingToken public stakingToken;
    IStakingWarmUp public stakingWarmUp;
    IUSMMinter public usmMinter;

    address public distributor;    
    address public _trustedForwarder;
    uint public warmupPeriod;


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

    function initialize(address owner_, address _trustedForwarderAddress) external initializer {
        _trustedForwarder = _trustedForwarderAddress;
        __Ownable_init();
        transferOwnership(owner_); //transfer ownership from proxyAdmin contract to deployer
    }

    function initialzeStaking(IERC20Upgradeable _D33D, IStakingToken _sD33D, address distributor_, address _stakingWarmUp, 
        uint _epochLength, uint _firstEpochNumber,
        uint _firstEpochTimestamp, uint warmUpPeriod_, address _DAO, address _usmMinter) external onlyOwner {

        require(address(D33D) == address(0), "Already initalized");

        D33D = _D33D;
        stakingToken = _sD33D;
        distributor = distributor_;
        warmupPeriod = warmUpPeriod_;
        DAO = _DAO;
        usmMinter = IUSMMinter(_usmMinter);

        epoch = Epoch({
            length: _epochLength,
            number: _firstEpochNumber,
            timestamp: _firstEpochTimestamp + _epochLength,
            distribute: 0
        });


        stakingWarmUp = IStakingWarmUp(_stakingWarmUp);

        D33D.safeApprove(_usmMinter, type(uint).max);
        
    }

    ///@notice Function to  deposit D33D. stakingToken will not be trensferred in this function.
    function stake(uint _amount, address _receiver) external returns (bool) {
        address _sender = _msgSender();

        rebase();

        D33D.safeTransferFrom(_sender, address(this), _amount);

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
        address _sender = _msgSender();

        Claim memory info = warmupInfo[_sender];

        if ( epoch.timestamp >= info.expiry && info.expiry != 0) { 
            delete warmupInfo[_sender];
            uint amount = stakingToken.balanceForGons(info.gons);
            
            stakingWarmUp.retrieve(_sender, amount);
        }
    }

    function claimRewards() external {
        address _sender = _msgSender();


        Claim memory info = warmupInfo[_sender];
        //difference in deposited amount and current sTOKEN amount are the rewards
        uint _amount = stakingToken.balanceForGons( info.gons );
        uint rewards = _amount - info.deposit;
        stakingWarmUp.retrieve(address(this), rewards);

        warmupInfo[_sender].gons = stakingToken.gonsForBalance( info.deposit );
        warmupInfo[_sender].expiry = epoch.timestamp +  warmupPeriod; //resets lockup period

        usmMinter.mintWithD33d(rewards, _sender);
    }

    function unStake(uint _amount, bool _trigger) external {
        address _sender = _msgSender();
        if(_trigger == true) {
            rebase();
        }
    
        stakingToken.safeTransferFrom( _sender, address(this), _amount );
        D33D.safeTransfer( _sender, _amount );
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

    function setWarmupPeriod(uint _warmupPeriod) external onlyOwner {
        warmupPeriod = _warmupPeriod;
    }

    function toggleDepositLock() external {
        warmupInfo[ msg.sender ].lock = !warmupInfo[ msg.sender ].lock;
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


}
