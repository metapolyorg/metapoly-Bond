//SPDX-License-Identifier : MIT
// pragma solidity 0.8.7;
pragma solidity 0.7.5;
import "../../libs/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../../libs/contracts-upgradeable/proxy/Initializable.sol";
import "../../libs/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "../../libs/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "../../libs/FixedPoint.sol";
import "../../libs/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";
import "../../libs/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IStaking {
    function stake(uint _amount, address _receiver) external returns (bool) ;
}

interface ITreasury {
    function deposit(uint amount, address principle, uint profit) external ;
    function depositNFT(uint _tokenId, address _token, uint _payout, uint _value) external returns (uint);
    function valueOf( address _token, uint _amount ) external view returns ( uint value_ );
}

interface IChainlink {
    function latestAnswer() external view returns (int256);
    function latestRoundData() external view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

interface Ioracle {
    function requestPriceUpdate() external;
}

contract BondNFT is Initializable, IERC721ReceiverUpgradeable {
    using SafeMathUpgradeable for uint;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using FixedPoint for *;

    IERC20Upgradeable public D33D;
    IERC721Upgradeable public principle;
    address public treasury;
    address public BondCalculator;
    address public Staking;
    address public DAO;
    address public admin;

    address public oracle; //contract that calls the price api

    bool public isLiquidityBond;

    Terms public terms; 
    Adjust public adjustment; 

    mapping(address => Bond) public bondInfo;

    uint public totalDebt; 
    uint public lastDecay; 

    uint priceInETH; 
    uint priceMarkdownPerc; //2 decimals // 5000 for 50%

    struct Terms {
        uint controlVariable; // scaling variable for price
        uint vestingTerm; // in blocks
        uint minimumPrice; // vs principle value
        uint maxPayout; // in thousandths of a %. i.e. 500 = 0.5%
        uint fee; // as % of bond payout, in hundreths. ( 500 = 5% = 0.05 for every 1 paid)
        uint maxDebt; // 9 decimal debt ratio, max % total supply created as debt
    }

    // Info for bond holder
    struct Bond {
        uint payout; // D33D remaining to be paid
        uint vesting; // Blocks left to vest
        uint lastTimestamp; // Last interaction
        uint pricePaid; // In USd, for front end viewing
        uint id;
    }

    // Info for incremental adjustments to control variable 
    struct Adjust {
        bool add; // addition or subtraction
        uint rate; // increment
        uint target; // BCV when adjustment finished
        uint buffer; // minimum length (in seconds) between adjustments
        uint lastTimestamp; // block timestamp when last adjustment made
    }

    enum PARAMETER { VESTING, PAYOUT, FEE, DEBT }

    event BondCreated( uint tokenId, uint indexed payout, uint indexed expires, uint indexed priceInUSD );
    event BondRedeemed( address indexed recipient, uint payout, uint remaining );
    event BondPriceChanged( uint indexed priceInUSD, uint indexed internalPrice, uint indexed debtRatio );
    event ControlVariableAdjustment( uint initialBCV, uint newBCV, uint adjustment, bool addition );
    event OracleChanged (address);

    modifier onlyAdmin {
        require(msg.sender == admin, "Only admin");
        _;
    }
    function initialize(address _D33D, address _principle, address _treasury, address _bondCalculator, 
        address _staking, address _DAO, address _admin, address _oracle) external initializer {
        D33D = IERC20Upgradeable(_D33D); 
        principle  = IERC721Upgradeable(_principle);
        treasury = _treasury;
        BondCalculator = _bondCalculator;
        Staking = _staking;
        DAO = _DAO;
        admin = _admin;

        isLiquidityBond = _bondCalculator != address(0);
        principle.setApprovalForAll(_treasury, true);

        oracle = _oracle;

        priceMarkdownPerc = 5000;
    }

    function initializeBondTerms( 
        uint _controlVariable, 
        uint _vestingTerm,
        uint _minimumPrice,
        uint _maxPayout,
        uint _fee,
        uint _maxDebt,
        uint _initialDebt
    ) external {
        require( terms.controlVariable == 0, "Bonds must be initialized from 0" );
        terms = Terms ({
            controlVariable: _controlVariable,
            vestingTerm: _vestingTerm,
            minimumPrice: _minimumPrice,
            maxPayout: _maxPayout,
            fee: _fee,
            maxDebt: _maxDebt
        });
        totalDebt = _initialDebt;
        lastDecay = block.timestamp; 

    }

    /**
        @notice Function to deposit principleToken. Principle token is deposited to treasury
        and D33D is minted. The minted D33D is vested for a specific time.
        @param _tokenId tokenId of principle token to deposit
        @param _maxPrice Used for slippage handling. Price in terms of principle token.
        @param _depositer address of User to receive bond D33D
     */

    function deposit(uint _tokenId, uint _maxPrice, address _depositer) external returns (uint) {
        require(_depositer != address(0), "Invalid address");

        decayDebt();
        require( totalDebt <= terms.maxDebt, "Max capacity reached" );

        (, uint priceInUSD) =  getPrice(); //uint value

        uint payout = payoutFor(priceInUSD);

        //payout increases when no new deposits
        require( payout >= 1e16, "Bond too small" ); // must be > 0.01 D33D ( underflow protection )
        uint fee = payout.mul(terms.fee).div(10000);

        principle.safeTransferFrom(msg.sender, address(this), _tokenId);

        ITreasury( treasury ).depositNFT( _tokenId, address(principle), payout.add(fee), priceInUSD); 

        if(fee > 0) {
            D33D.safeTransfer(DAO, fee);
        }

        // total debt is increased
        totalDebt = totalDebt.add( priceInUSD * 10000 / priceMarkdownPerc ); //add price paid by user(unmarkdowned)
                
        // depositor info is stored
        bondInfo[ _depositer ] = Bond({ 
            payout: bondInfo[ _depositer ].payout.add( payout ),
            vesting: terms.vestingTerm,
            lastTimestamp: block.timestamp,
            pricePaid: priceInUSD,
            id: _tokenId
        });

        // indexed events are emitted
        emit BondCreated( _tokenId, payout, block.number.add( terms.vestingTerm ), priceInUSD );
        emit BondPriceChanged( bondPriceInUSD(), _bondPrice(), debtRatio() );

        adjust(); // control variable is adjusted
        return payout;

    }

    ///@notice Used by treasury to trigger a price update
    function requestPriceUpdate() external {
        require(msg.sender == address(treasury), "Only treasury");
        Ioracle(oracle).requestPriceUpdate();
    }

    function setPrice(uint _price) external {
        require(msg.sender == address(treasury) || 
            msg.sender == address(oracle), "Only treasury or priceOracle");
        
        priceInETH = _price.mul(priceMarkdownPerc).div(10000);
    }

    ///@return _priceInETH floor price of collection is ETH (18 decimals)
    ///@return _priceInUSD floor price of collection is USD (18 decimals)
    function getPrice() public view returns (uint _priceInETH, uint _priceInUSD) {
        _priceInETH = priceInETH;
        //0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419 - mainnet
        (,int _price,,,) = IChainlink(0x9326BFA02ADD2366b30bacB125260Af641031331).latestRoundData();
        // (,int _price,,,) = IChainlink(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419).latestRoundData();

        _priceInUSD = priceInETH * uint(_price) / (1e8);
    }

    ///@notice Function to set the price markdown percentage. 
    function setMarkdownValue(uint _perc) external {
        require(msg.sender == address(treasury), "Only treasury");
        priceMarkdownPerc = _perc;
    }

    function changeOracle(address _oracle) external onlyAdmin {
        oracle = _oracle;
        emit OracleChanged(_oracle);
    }

    /**
        @notice Function to redeem/stake the vested D33D.
        @param _recipient Address to redeem
        @param _stake Whether to stake/redeem the vested D33D
     */
    function redeem( address _recipient, bool _stake ) external returns ( uint ) {        
        Bond memory info = bondInfo[ _recipient ];
        uint percentVested = percentVestedFor( _recipient ); // (blocks since last interaction / vesting term remaining)

        if ( percentVested >= 10000 ) { // if fully vested
            delete bondInfo[ _recipient ]; // delete user info
            return stakeOrSend( _recipient, _stake, info.payout ); // pay user everything due

        } else { // if unfinished
            // calculate payout vested
            uint payout = info.payout .mul(percentVested).div(10000);

            // store updated deposit info
            bondInfo[ _recipient ] = Bond({
                payout: info.payout.sub( payout ),
                vesting: info.vesting - (block.timestamp - info.lastTimestamp),
                lastTimestamp: block.timestamp,
                pricePaid: info.pricePaid,
                id: info.id
            });

            emit BondRedeemed( _recipient, payout, bondInfo[ _recipient ].payout );            
            return stakeOrSend( _recipient, _stake, payout );
        }
    }

    function stakeOrSend( address _recipient, bool _stake, uint _amount ) internal returns ( uint ) {
        if ( !_stake ) { // if user does not want to stake
            D33D.safeTransfer( _recipient, _amount ); // send payout
        } else { // if user wants to stake
                D33D.approve( Staking, _amount );
                IStaking( Staking ).stake( _amount, _recipient );
        }
        return _amount;
    }    

    /**
        @notice Function to get the amount of D33D that can be redeemed.
        @param _depositor address of user
        @return pendingPayout_ Quantity of D33D that can be redeemed
     */
    function pendingPayoutFor( address _depositor ) external view returns ( uint pendingPayout_ ) {
        uint percentVested = percentVestedFor( _depositor );
        uint payout = bondInfo[ _depositor ].payout;
        if ( percentVested >= 10000 ) {
            pendingPayout_ = payout;
        } else {
            pendingPayout_ = payout.mul(percentVested).div(10000);
        }
    }

    /**
        @notice Function to increase or decrease the BCV
        @param _addition To increase/decrease the BCV. True to increase 
        @param _target Target BCV
        @param _increment Rate of increase per _buffer
        @param _buffer Minimum time between adjustment
     */
    function setAdjustment ( 
        bool _addition,
        uint _increment, 
        uint _target,
        uint _buffer 
    ) external onlyAdmin {
        require( _increment <= terms.controlVariable.mul( 25 ).div( 1000 ), "Increment too large" );

        adjustment = Adjust({
            add: _addition,
            rate: _increment,
            target: _target,
            buffer: _buffer,
            lastTimestamp: block.timestamp
        });
    }

    function setBondTerms ( PARAMETER _parameter, uint _input ) external onlyAdmin {
        if ( _parameter == PARAMETER.VESTING ) { // 0
            require( _input >= 10000, "Vesting must be longer than 36 hours" );
            terms.vestingTerm = _input;
        } else if ( _parameter == PARAMETER.PAYOUT ) { // 1
            terms.maxPayout = _input;
        } else if ( _parameter == PARAMETER.FEE ) { // 2
            require( _input <= 10000, "DAO fee cannot exceed payout" );
            terms.fee = _input;
        } else if ( _parameter == PARAMETER.DEBT ) { // 3
            terms.maxDebt = _input;
        }
    }


    function adjust() internal {
        uint blockCanAdjust = adjustment.lastTimestamp + adjustment.buffer;
        if( adjustment.rate != 0 && block.timestamp >= blockCanAdjust ) {
            uint initial = terms.controlVariable;
            if ( adjustment.add ) {
                terms.controlVariable = terms.controlVariable + adjustment.rate;
                if ( terms.controlVariable >= adjustment.target ) {
                    adjustment.rate = 0;
                }
            } else {
                terms.controlVariable = terms.controlVariable - adjustment.rate;
                if ( terms.controlVariable <= adjustment.target ) {
                    adjustment.rate = 0;
                }
            }
            adjustment.lastTimestamp = block.timestamp;
            emit ControlVariableAdjustment( initial, terms.controlVariable, adjustment.rate, adjustment.add );
        }
    }

    function percentVestedFor( address _depositor ) public view returns ( uint percentVested_ ) {
        Bond memory bond = bondInfo[ _depositor ];
        uint timeSinceLast = block.timestamp - bond.lastTimestamp;
        uint vesting = bond.vesting;


        if ( vesting > 0 ) {
            percentVested_ = timeSinceLast .mul(10000).div(vesting);
        } else {
            percentVested_ = 0;
        }

    }

    ///@return price_ price in usd (18 decimals)
    function bondPriceInUSD() public view returns ( uint price_ ) {
        return bondPrice();
    }

    ///@return price_ price interms of principle token (18 decimals)
    function bondPrice() public view returns ( uint price_ ) {        
        price_ = terms.controlVariable.mul( debtRatio() ).div( 1e6 ).add(1e17);

        if ( price_ < terms.minimumPrice ) {
            price_ = terms.minimumPrice;
        }

    }

    function _bondPrice() internal returns ( uint price_ ) {        
        price_ = terms.controlVariable.mul( debtRatio() ).div( 1e6 ).add(1e17);

        if ( price_ < terms.minimumPrice ) {
            price_ = terms.minimumPrice;        
        }
    }
        
    ///@param _value Value in USD (18 decimals)
    ///@return Returns quantity of D33D for the value
    function payoutFor( uint _value ) public view returns ( uint ) {
        return _value.mul(1e18).div(bondPrice());
    }

    function debtRatio() public view returns ( uint debtRatio_ ) {   
        uint supply = D33D.totalSupply();
        if(supply == 0) {
            return 0;
        }
        debtRatio_ = FixedPoint.fraction( 
            currentDebt().mul( 1e18 ), 
            supply
        ).decode112with18().div( 1e18 );
        //18 decimals

    }

    function currentDebt() public view returns ( uint ) {
        return totalDebt - debtDecay();
    }

    function decayDebt() internal {
        totalDebt = totalDebt - debtDecay() ;
        lastDecay = block.timestamp;
    }

    function debtDecay() public view returns ( uint decay_ ) {
        uint timesSinceLast = block.timestamp - lastDecay;
        decay_ = totalDebt .mul (timesSinceLast) .div (terms.vestingTerm);
        if ( decay_ > totalDebt ) {
            decay_ = totalDebt;
        }
    }

    function maxPayout() public view returns ( uint ) {
        return D33D.totalSupply().mul( terms.maxPayout ).div( 100000 );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override pure returns (bytes4) {
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }

    function setMinimumPrice(uint _minimumPrice) external onlyAdmin {
        terms.minimumPrice = _minimumPrice;
    }
}
