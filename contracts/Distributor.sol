//SPDX-License-Identifier: MIT
pragma solidity 0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface ITreasury {
    function mintRewards(address receiver_, uint amount_) external;
}

interface IStakingToken is IERC20Upgradeable {
    function unStake(uint _amount, bool _trigger) external ;
}

contract Distributor is Initializable, OwnableUpgradeable{

    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC20Upgradeable public D33D;
    ITreasury public Treasury;

    uint epochLength;
    uint nextEpochTimestamp;

    address[] public penaltyRewardReceivers; //list of contracts that receive the penalty rewards(locked-staking contracts)

    struct Info {
        uint rate; // in ten-thousandths ( 5000 = 0.5% )
        address recipient;
        address stakingToken;
    }

    Info[] public info;
    
    struct Adjust {
        bool add;
        uint rate;
        uint target;
    }

    mapping( uint => Adjust ) public adjustments;
    function initialize(address D33D_, address treasury_, uint epochLength_, uint nextEpochTimestamp_, address admin_) external initializer {
        __Ownable_init();

        Treasury = ITreasury(treasury_);
        D33D = IERC20Upgradeable(D33D_);

        epochLength = epochLength_;
        nextEpochTimestamp = nextEpochTimestamp_;
        transferOwnership(admin_);
    }

    function distribute() external returns (bool) {
        if(nextEpochTimestamp <= block.timestamp) {
            nextEpochTimestamp = nextEpochTimestamp + epochLength;
            for(uint i; i< info.length; i++) {
                if(info[i].rate > 0) {
                    Treasury.mintRewards(info[i].recipient, nextRewardAt(info[i].rate));
                    adjust(i);

                    getPenaltyRewards(IStakingToken(info[i].stakingToken));
                }
            }

            distributePenaltyRewards();
            return true;
        } 
    }

    ///@dev checks whether penalty rewards are received. If received, collect and distribute
    function getPenaltyRewards(IStakingToken stakingToken_) internal {
        if(address(stakingToken_)!= address(0)) {
            uint _amount = stakingToken_.balanceOf(address(this));
            if(_amount >0) {
                stakingToken_.unStake(_amount, false); //SHOULD be false always
            }
        }
    }

    function distributePenaltyRewards() internal {
        uint balance = D33D.balanceOf(address(this));
        if(balance > 0) {
            uint totalReceivers = penaltyRewardReceivers.length;
            uint amtToDistribute = balance / penaltyRewardReceivers.length;

            for(uint i; i< totalReceivers; i++){
                D33D.safeTransfer(penaltyRewardReceivers[i], amtToDistribute);
            }

        }
    }

    function adjust(uint index_) internal {
        Adjust memory adjustment = adjustments[index_];

        if(adjustment.rate > 0) {
            if(adjustment.add) {
                info[index_].rate = info[index_].rate + adjustment.rate;
                if(info[index_].rate >= adjustment.target) {
                    adjustments[index_].rate = 0;
                }
            } else {
                info[index_].rate = info[index_].rate - adjustment.rate;
                if(info[index_].rate <= adjustment.target) {
                    adjustments[index_].rate = 0;
                }
            }
        }
    }

    function nextRewardAt(uint rate_) public view returns (uint) {
        return D33D.totalSupply() * rate_ / 1000000;
    }

    function nextRewardFor( address recipient_ ) public view returns ( uint ) {
        uint reward;
        for ( uint i = 0; i < info.length; i++ ) {
            if ( info[ i ].recipient == recipient_ ) {
                reward = nextRewardAt( info[ i ].rate );
            }
        }
        return reward;
    }

    /**
        @param receiver_ reward receiver (staking contracts)
        @param stakingToken_ stakingToken of stakingContract (sD33D etc).
        @param rate_ % of rewards (50000 for 5%)
     */
    function addRecipient(address receiver_, address stakingToken_, uint rate_) external onlyOwner {
        require(receiver_ != address(0), "Invalid Receiver");
        info.push(Info({
            recipient: receiver_,
            rate: rate_,
            stakingToken: stakingToken_
        }));
    }

    ///@param penaltyRewardReceivers_ array of all penalty reward receivers (locked staking contracts)
    function updatePenaltyRewardReceivers(address[] memory penaltyRewardReceivers_) external onlyOwner {
        penaltyRewardReceivers = penaltyRewardReceivers_;
    }

    function removeRecipient(address recipient_, uint index_) external onlyOwner {
        require(recipient_ == info[index_].recipient, "Invalid address");

        info[index_].recipient = address(0);
        info[index_].stakingToken = address(0);
        info[index_].rate = 0;

    }

    function setAdjustment( uint index_, bool add_, uint rate_, uint target_ ) external onlyOwner {
        adjustments[ index_ ] = Adjust({
            add: add_,
            rate: rate_,
            target: target_
        });
    }
}