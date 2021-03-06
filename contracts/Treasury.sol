pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

interface IBondCalculator {
  function valuation( address pair_, uint amount_ ) external view returns ( uint _value );
}

interface ID33D is IERC20Upgradeable{
    function mint(address, uint amount) external;
    function burnFrom(address, uint amount) external;

    function decimals() external view returns(uint8);
}

interface IToken is IERC20Upgradeable {
    function decimals() external view returns(uint8);
    function mint(address to, uint amount) external;
    function burn(uint amount) external;
}

interface INFTBond {
    function priciple() external view returns(address);
    function requestPriceUpdate() external;
    function setPrice(uint _price) external;
    function getPrice() external view returns (uint _priceInETH, uint _priceInUSD);

    function setMarkdownValue(uint _perc) external ;
}

contract Treasury is Initializable, OwnableUpgradeable, IERC721ReceiverUpgradeable {

    using SafeERC20Upgradeable for ID33D;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    ID33D public D33D;

    address[] public reserveTokens; // Push only, beware false-positives.
    mapping( address => bool ) public isReserveToken;

    address[] public reserveDepositors; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isReserveDepositor;

    address[] public reserveSpenders; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isReserveSpender;

    address[] public liquidityTokens; // Push only, beware false-positives.
    mapping( address => bool ) public isLiquidityToken;

    address[] public liquidityDepositors; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isLiquidityDepositor;

    mapping( address => address ) public bondCalculator; // bond calculator for liquidity token

    address[] public reserveManagers; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isReserveManager;

    address[] public liquidityManagers; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isLiquidityManager;

    address[] public debtors; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isDebtor;
    mapping( address => uint ) public debtorBalance;

    address[] public rewardManagers; // Push only, beware false-positives. Only for viewing.
    mapping( address => bool ) public isRewardManager;

    address[] public supportedNFTs; // Push only, beware false-positives. Only for viewing.
    mapping(address => bool)public isSupportedNFT;

    address[] public nftDepositors; // Push only, beware false-positives. Only for viewing.
    mapping(address => bool)public isNFTDepositor;

    uint public totalReserves; // Risk-free value of all assets

    uint public d33dPrice; //should not be used as oracle

    enum MANAGING { RESERVEDEPOSITOR, RESERVESPENDER, RESERVETOKEN, RESERVEMANAGER, LIQUIDITYDEPOSITOR, 
        LIQUIDITYTOKEN, LIQUIDITYMANAGER, REWARDMANAGER, NFTDEPOSITOR, SUPPORTEDNFT  }

    address public bD33D;
    
    event Deposit( address indexed token, uint amount, uint value );
    event DepositNFT( address indexed token, uint id, uint value );
    event Withdrawal( address indexed token, uint amount, uint value );
    event RewardsMinted( address indexed caller, address indexed recipient, uint amount );
    event ChangeActivated( MANAGING indexed managing, address activated, bool result );
    event ReservesManaged( address indexed token, uint amount );
    event ReservesUpdated( uint indexed totalReserves );
    event ReservesAudited( uint indexed totalReserves );

    function initialize(address _d33d,         
        address _USDC,
        address owner_, uint d33dPrice_, address _bD33D) external initializer {
        __Ownable_init();

        d33dPrice = d33dPrice_;
        D33D = ID33D(_d33d);
        bD33D = _bD33D;

        isReserveToken[ _USDC ] = true;
        reserveTokens.push( _USDC );

        transferOwnership(owner_);
    }

    function updateD33dPrice(uint d33dPrice_) external onlyOwner{
        d33dPrice = d33dPrice_;
    }

    function depositNFT(uint _tokenId, address _token, uint _payout, uint _value) external returns (uint) {
        require(isSupportedNFT[_token], "Not accepted");
        require(isNFTDepositor[msg.sender], "Not approved");

        IERC721Upgradeable(_token).safeTransferFrom(msg.sender, address(this), _tokenId);

        _mint(msg.sender, _payout);

        totalReserves = totalReserves + _value;
        emit ReservesUpdated( totalReserves );

        emit DepositNFT( _token, _tokenId, _value );
        return _payout;
    }

    function requestNFTPrice() external onlyOwner{
        for (uint i=0; i < nftDepositors.length; i++) {
            if(isNFTDepositor[nftDepositors[i]]) {
                INFTBond(nftDepositors[i]).requestPriceUpdate();
            }
        }
    }

    ///@notice Enables the community to set a floor price.
    function setPrice(address _contract, uint _price) external onlyOwner {
        INFTBond(_contract).setPrice(_price);
    }

    function setMarkdown(address _bond, uint _perc) external onlyOwner {
        require(isNFTDepositor[_bond], "Invalid bond address");
        INFTBond(_bond).setMarkdownValue(_perc);
    }

    function depositBond(uint _amount, address _token, uint _payout) external returns (uint) {
        require(isLiquidityToken[_token], "Not accepted");
        IERC20Upgradeable( _token ).safeTransferFrom( msg.sender, address(this), _amount );

        require(isLiquidityDepositor[msg.sender], "Not approved");

        uint value = lpValuation(_amount, _token); //value from bondCalc

        _mint(msg.sender, _payout);

        totalReserves = totalReserves + value;
        emit ReservesUpdated( totalReserves );

        emit Deposit( _token, _amount, value );
        return _payout;

    }

    function lpValuation(uint _amount, address _token) public view returns (uint) {
        return IBondCalculator( bondCalculator[ _token ] ).valuation( _token, _amount );
    }

    function auditReserves() external onlyOwner {
        uint reserves;
        for( uint i = 0; i < reserveTokens.length; i++ ) {
            reserves = reserves + ( 
                valueOf( reserveTokens[ i ], IERC20Upgradeable( reserveTokens[ i ] ).balanceOf( address(this) ) )
            );
        }

        for( uint i = 0; i < liquidityTokens.length; i++ ) {
            reserves = reserves + lpValuation(IERC20Upgradeable( liquidityTokens[ i ] ).balanceOf( address(this) ), liquidityTokens[ i ]);
        }

        for(uint i=0; i< nftDepositors.length; i++) {
            if(isNFTDepositor[nftDepositors[i]]) {
                (,uint priceUSD) = INFTBond(nftDepositors[i]).getPrice();
                reserves = reserves + priceUSD;
            }
        }

        totalReserves = reserves;
        emit ReservesUpdated( reserves );
        emit ReservesAudited( reserves );
    }

    function deposit( uint _amount, address _token, uint _profit ) external returns ( uint send_ ) {
        require( isReserveToken[ _token ] || isLiquidityToken[ _token ], "Not accepted" );
        IERC20Upgradeable( _token ).safeTransferFrom( msg.sender, address(this), _amount );

        if ( isReserveToken[ _token ] ) {
            require( isReserveDepositor[ msg.sender ], "Not approved" );
        } else {
            require( isLiquidityDepositor[ msg.sender ], "Not approved" );
        }

        uint value = valueOf( _token, _amount );

        // mint D33D needed and store amount of rewards for distribution
        send_ = (value -  _profit) * 1e18 / d33dPrice;
        _mint(msg.sender, send_);
        //value - send_ is protocol profit
        totalReserves = totalReserves + value ;
        emit ReservesUpdated( totalReserves );

        emit Deposit( _token, _amount, value );
    }

    function withdraw( uint _amount, address _token ) external {
        require( isReserveToken[ _token ], "Not accepted" ); // Only reserves can be used for redemptions
        require( isReserveSpender[ msg.sender ] == true, "Not approved" );

        uint value = valueOf( _token, _amount );
        uint quantity = value * 1e18 / d33dPrice;

        D33D.burnFrom( msg.sender, quantity );

        totalReserves = totalReserves - value ;
        emit ReservesUpdated( totalReserves );
        
        IERC20Upgradeable( _token ).safeTransfer( msg.sender, _amount );
        emit Withdrawal( _token, _amount, value );

    }

    ///@param _tokenId Id of the NFT
    ///@param _bond Bond contract of the nft
    function manageNFT(uint _tokenId, address _bond) external {
        require(isReserveManager[msg.sender], "not approved");
        address token = INFTBond(_bond).priciple();
        require(isSupportedNFT[token], "Not accepted");

        (,uint value) = INFTBond(_bond).getPrice();

        require( value <= excessReserves(), "reserves" );
        
        totalReserves = totalReserves - value;
        emit ReservesUpdated( totalReserves );

        IERC721Upgradeable(token).safeTransferFrom(address(this), msg.sender, _tokenId);
        
    }

    ///@param _amount amount of _token(not d33d)
    function manage( address _token, uint _amount ) external {
        uint value;

        if( isLiquidityToken[ _token ] ) {
            require( isLiquidityManager[ msg.sender ], "Not approved" );
            value = lpValuation(_amount, _token);
        } else {
            require( isReserveManager[ msg.sender ], "Not approved" );
            value = valueOf( _token, _amount );
        }

        
        require( value <= excessReserves(), "reserves" );

        totalReserves = totalReserves - value;
        emit ReservesUpdated( totalReserves );

        IERC20Upgradeable( _token ).safeTransfer( msg.sender, _amount );
        emit ReservesManaged( _token, _amount );

    }

    function mintRewards( address _recipient, uint _amount ) external {
        require( isRewardManager[ msg.sender ], "Not approved" );
        require( _amount <= excessReserves(), "reserves" );

        _mint(_recipient, _amount);

        emit RewardsMinted( msg.sender, _recipient, _amount );
    } 

    function _mint(address _user, uint _amount) internal {
        IToken(bD33D).mint(address(this), _amount);
        IToken(bD33D).burn(_amount);
        D33D.mint( _user, _amount );
    }


    function valueOf( address _token, uint _amount ) public view returns ( uint value_ ) {
        value_ = _amount * ( 10 ** D33D.decimals() ) / ( 10 ** IToken( _token ).decimals() );
    }

    function excessReserves() public view returns ( uint ) {
        return totalReserves - (D33D.totalSupply() * d33dPrice / 1e18);
    }

    //toggle() can be used instead of editPermission()
    /* function editPermission(MANAGING _managing, address _address, bool _status) external onlyOwner returns (bool) {
        require( _address != address(0) );
        
        if ( _managing == MANAGING.RESERVEDEPOSITOR ) { // 0
            isReserveDepositor[_address] = _status;
        } else if ( _managing == MANAGING.RESERVESPENDER ) { // 1
            isReserveSpender[_address] = _status;
        } else if ( _managing == MANAGING.RESERVETOKEN ) { // 2
            isReserveToken[_address] = _status;
        } else if ( _managing == MANAGING.RESERVEMANAGER ) { // 3
            isReserveManager[_address] = _status;
        } else if ( _managing == MANAGING.LIQUIDITYDEPOSITOR ) { // 4
            isLiquidityDepositor[_address] = _status;
        } else if ( _managing == MANAGING.LIQUIDITYTOKEN ) { // 5
            isLiquidityToken[_address] = _status;
        } else if ( _managing == MANAGING.LIQUIDITYMANAGER ) { // 6
            isLiquidityManager[_address] = _status;
        } else if ( _managing == MANAGING.REWARDMANAGER ) { // 7
            isRewardManager[_address] = _status;
        } else if ( _managing == MANAGING.NFTDEPOSITOR ) { // 8
            isNFTDepositor[_address] = _status;
        } else if ( _managing == MANAGING.SUPPORTEDNFT ) { // 9
            isSupportedNFT[_address] = _status;
        } else return false;
    } */

    function toggle( MANAGING _managing, address _address, address _calculator ) external onlyOwner returns ( bool ) {
        require( _address != address(0) );
        bool result;
        if ( _managing == MANAGING.RESERVEDEPOSITOR ) { // 0
            if( !listContains( reserveDepositors, _address ) ) {
                reserveDepositors.push( _address );
            }
            result = !isReserveDepositor[ _address ];
            isReserveDepositor[ _address ] = result;
            
        } else if ( _managing == MANAGING.RESERVESPENDER ) { // 1
            if( !listContains( reserveSpenders, _address ) ) {
                reserveSpenders.push( _address );
            }
            result = !isReserveSpender[ _address ];
            isReserveSpender[ _address ] = result;

        } else if ( _managing == MANAGING.RESERVETOKEN ) { // 2
            if( !listContains( reserveTokens, _address ) ) {
                reserveTokens.push( _address );
            }
            result = !isReserveToken[ _address ];
            isReserveToken[ _address ] = result;

        } else if ( _managing == MANAGING.RESERVEMANAGER ) { // 3
            if( !listContains( reserveManagers, _address ) ) {
                reserveManagers.push( _address );
            }
            
            result = !isReserveManager[ _address ];
            isReserveManager[ _address ] = result;

        } else if ( _managing == MANAGING.LIQUIDITYDEPOSITOR ) { // 4
            if( !listContains( liquidityDepositors, _address ) ) {
                liquidityDepositors.push( _address );
            }
            result = !isLiquidityDepositor[ _address ];
            isLiquidityDepositor[ _address ] = result;

        } else if ( _managing == MANAGING.LIQUIDITYTOKEN ) { // 5
            if( !listContains( liquidityTokens, _address ) ) {
                liquidityTokens.push( _address );
            }
            result = !isLiquidityToken[ _address ];
            isLiquidityToken[ _address ] = result;
            bondCalculator[ _address ] = _calculator;

        } else if ( _managing == MANAGING.LIQUIDITYMANAGER ) { // 6
            if( !listContains( liquidityManagers, _address ) ) {
                liquidityManagers.push( _address );
            }
            result = !isLiquidityManager[ _address ];
            isLiquidityManager[ _address ] = result;

        } else if ( _managing == MANAGING.REWARDMANAGER ) { // 7
            if( !listContains( rewardManagers, _address ) ) {
                rewardManagers.push( _address );
            }
            result = !isRewardManager[ _address ];
            isRewardManager[ _address ] = result;

        } else if ( _managing == MANAGING.NFTDEPOSITOR ) { // 8
            if( !listContains( rewardManagers, _address ) ) {
                nftDepositors.push( _address );
            }
            result = !isNFTDepositor[ _address ];
            isNFTDepositor[ _address ] = result;

        } else if ( _managing == MANAGING.SUPPORTEDNFT ) { // 9
            if( !listContains( rewardManagers, _address ) ) {
                supportedNFTs.push( _address );
            }
            result = !isSupportedNFT[ _address ];
            isSupportedNFT[ _address ] = result;

        } else return false;

        emit ChangeActivated( _managing, _address, result );
        return true;
    }


    function listContains( address[] storage _list, address _token ) internal view returns ( bool ) {
        for( uint i = 0; i < _list.length; i++ ) {
            if( _list[ i ] == _token ) {
                return true;
            }
        }
        return false;
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

}