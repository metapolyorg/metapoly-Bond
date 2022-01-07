// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IChainlink {
    function latestAnswer() external view returns (int256);
}

interface IUNIPair {
    function getReserves() external view returns (uint, uint);
    function token0() external view returns (address);
}

interface IRouter {
    function getAmountsOut(uint, address[] memory) external view returns (uint[] memory);
}

contract BondingCalculatorD33D_ETH is Initializable, OwnableUpgradeable{

    address public D33D;
    address public WETH;
    IUNIPair public pair;
    IRouter public router;
    IChainlink public oracleETH_USD;
    uint markdownPerc; //2 decimals 5000 for 50%
    uint oracleDecimals;
    function initialize( uint markdownPerc_, address admin_, IChainlink _oracleETH_USD, IUNIPair _pair, 
        address _D33D, IRouter _router, address _WETH) external initializer{
        
        D33D = _D33D;
        WETH = _WETH;
        router = _router;
        markdownPerc = markdownPerc_;
        oracleETH_USD = _oracleETH_USD;
        pair = _pair;

        __Ownable_init();

        transferOwnership(admin_);
    }

    function changeMarkdownPerc(uint newPerc_) external onlyOwner {
        markdownPerc = newPerc_;
    }

    function lpPrice() internal view returns (uint) {
        (uint reserve0, uint reserve1) = pair.getReserves();
        if(pair.token0() != D33D) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }

        //get d33d price in ETH
        address[] memory path = new address[](2);
        path[0] = D33D;
        path[1] = WETH;
        uint _priceInETH = router.getAmountsOut(1e18, path)[1];

        uint valueInETH = (_priceInETH * reserve0) / 1e18 + reserve1;

        return uint(oracleETH_USD.latestAnswer()) * valueInETH / 1e8 ;
    }
    ///@return _value MarkdownPrice in usd (18 decimals)
    function valuation( address strategy_, uint amount_ ) external view returns ( uint _value ) {
        
        return amount_ * lpPrice() * markdownPerc / 1e22;
    }

    ///@return Mardown price of 1 token in USD (18 decimals)
    function markdown( address strategy_ ) external view returns ( uint ) {
                return lpPrice() * markdownPerc / 10000;
    }

    ///@return Price of LP token in USD (18 decimals)
    function getRawPrice() external view returns (uint) {
        return lpPrice();
    }
    
}
