pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface ITreasury {
    function deposit(uint _amount, address _token, uint _profit) external returns (uint);
    function d33dPrice() external view returns (uint);
}

interface IERC20 is IERC20Upgradeable {
    function decimals() external view returns (uint);
    function burnFrom(address, uint) external;
}

contract pD33DRedeemerImplementation is Initializable, OwnableUpgradeable {

    using SafeERC20Upgradeable for IERC20;

    IERC20 public D33D;
    IERC20 public pD33D;
    ITreasury public treasury;

    struct Term {
        uint percent; // 4 decimals ( 5000 = 0.5% )
        uint claimed;
        uint max;
    }

    mapping( address => Term ) public terms;
    
    mapping( address => address ) public walletChange;
    
    function initialize(IERC20 _D33D, IERC20 _pD33D, ITreasury _treasury) external initializer {
        D33D = _D33D;
        pD33D = _pD33D;
        treasury = _treasury;

        __Ownable_init();
    }

    ///@param _vester user address
    ///@param _amountCanClaim allocated pTOKEN
    ///@param _rate supplyshare 2 decimals (500 for 5% supplyshare)
    function setTerms(address _vester, uint _amountCanClaim, uint _rate ) external onlyOwner returns ( bool ) {
        require( _amountCanClaim >= terms[ _vester ].max, "cannot lower amount claimable" );
        require( _rate >= terms[ _vester ].percent, "cannot lower vesting rate" );

        terms[ _vester ].max = _amountCanClaim;
        terms[ _vester ].percent = _rate;

        return true;
    }

    function exercise( uint _amount, address _token ) external returns ( bool ) {
        Term memory info = terms[ msg.sender ];
        require( redeemable( info ) >= _amount, 'Not enough vested' );
        require( info.max -  info.claimed >= _amount, 'Claimed over max' );

        uint principleAmount = (_amount * treasury.d33dPrice() / 1e18) * IERC20( _token ).decimals() / 1e18;
        IERC20( _token ).safeTransferFrom( msg.sender, address( this ), principleAmount );
        pD33D.burnFrom( msg.sender, _amount );
        
        IERC20( _token ).approve( address(treasury), principleAmount );
        uint amt = treasury.deposit( principleAmount, _token, 0);

        terms[ msg.sender ].claimed = info.claimed +  _amount;

        D33D.safeTransfer( msg.sender, amt );

        return true;
    }

    function redeemableFor( address _vester ) public view returns (uint) {
        return redeemable( terms[ _vester ]);
    }
    
    function redeemable( Term memory _info ) internal view returns ( uint ) {
        return ( D33D.totalSupply() *_info.percent / 10000 ) - ( _info.claimed );
    }

    // Allows wallet owner to transfer rights to a new address
    function pushWalletChange( address _newWallet ) external returns ( bool ) {
        require( terms[ msg.sender ].percent != 0 );
        walletChange[ msg.sender ] = _newWallet;
        return true;
    }
    
    // Allows wallet to pull rights from an old address
    function pullWalletChange( address _oldWallet ) external returns ( bool ) {
        require( walletChange[ _oldWallet ] == msg.sender, "wallet did not push" );
        
        walletChange[ _oldWallet ] = address(0);
        terms[ msg.sender ] = terms[ _oldWallet ];
        delete terms[ _oldWallet ];
        
        return true;
    }
    
}