pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";

interface ITreasury {
    function deposit(uint _amount, address _token, uint _profit) external returns (uint);
    function d33dPrice() external view returns (uint);
}

interface IStakingContract {
    function stake(uint _amount, address _receiver) external;
}

interface IERC20 is IERC20Upgradeable {
    function burnFrom(address, uint) external;
}

contract pD33DRedeemer is Initializable, OwnableUpgradeable {

    IERC20 public D33D;
    IERC20 public pD33D;
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ITreasury public treasury;
    IStakingContract public stakingContract;
    address public signer;

    struct Term {
        uint percent; // 4 decimals ( 5000 = 0.5% )
        uint claimed;
        uint max;
    }

    mapping( address => Term ) public terms;
    
    function initialize(IERC20 _D33D, IERC20 _pD33D, address _signer) external initializer {
        D33D = _D33D;
        pD33D = _pD33D;
        signer = _signer;

        __Ownable_init();
    }

    ///@param _vester user address
    ///@param _amountCanClaim allocated pTOKEN
    ///@param _rate supply share 2 decimals (500 for 5% supplyshare)
    function setTerms(address _vester, uint _amountCanClaim, uint _rate ) external onlyOwner {
        require( _amountCanClaim >= terms[ _vester ].max, "cannot lower amount claimable" );

        terms[ _vester ].max = _amountCanClaim;
        terms[ _vester ].percent = _rate;
    }

    /// @param _amount Aount of D33D to redeem (1 pD33D = 1 D33D)
    function redeem( uint _amount, bytes calldata _signature, bool _stake ) external {
        if (_signature.length == 0) { // No signature, whitelisted in contract
            Term memory info = terms[ msg.sender ];
            require(info.percent != 0, "Not whitelisted");
            require( redeemable( info ) >= _amount, 'Not enough vested' );
            require( info.max -  info.claimed >= _amount, 'Claimed over max' );

            terms[ msg.sender ].claimed = info.claimed +  _amount;
        } else {
            require(terms[msg.sender].percent == 0, "On-chain whitelisted");
            bytes32 message = keccak256(abi.encodePacked(msg.sender));
            bytes32 messageHash = ECDSAUpgradeable.toEthSignedMessageHash(message);
            address recoveredAddr = ECDSAUpgradeable.recover(messageHash, _signature);
            require(recoveredAddr == signer, "Invalid signature");
        }

        uint USDCAmt = (_amount * treasury.d33dPrice() / 1e30);
        USDC.transferFrom( msg.sender, address( this ), USDCAmt );
        pD33D.burnFrom( msg.sender, _amount );
        
        uint D33DAmt = treasury.deposit( USDCAmt, address(USDC), 0);

        if (_stake) {
            stakingContract.stake(D33DAmt, msg.sender);
        } else {
            D33D.transfer( msg.sender, D33DAmt );
        }
    }

    function redeemableFor( address _vester ) external view returns (uint) {
        uint pD33DAmt = pD33D.balanceOf(_vester);
        if (terms[ _vester ].percent != 0) { // On-chain whitelisted
            uint _reedeemable = redeemable( terms[ _vester ]);
            if (pD33D.balanceOf(_vester) > _reedeemable) return _reedeemable;
            else return pD33DAmt;
        } else {
            return pD33DAmt;
        }
    }
    
    function redeemable( Term memory _info ) internal view returns ( uint ) {
        return ( D33D.totalSupply() *_info.percent / 10000 ) - ( _info.claimed );
    }

    function changeWhitelistedAddress( address _newWallet ) external {
        require( terms[ msg.sender ].percent != 0 );
        terms[ _newWallet ] = terms[ msg.sender ];
        delete terms[ msg.sender ];
    }

    function setTreasury(ITreasury _treasury) external onlyOwner {
        treasury = _treasury;
        USDC.approve(address(_treasury), type(uint).max);
    }

    function setStakingContract(IStakingContract _stakingContract) external onlyOwner {
        stakingContract = _stakingContract;
        D33D.approve(address(stakingContract), type(uint).max);
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function isContractWhitelisted(address _account) external view returns (bool) {
        if (terms[ _account ].percent != 0) return true;
        else return false;
    }
}