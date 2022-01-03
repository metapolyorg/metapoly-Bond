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
    function totalSupply() external view returns (uint);
}

interface IRouter {
    function getAmountsOut(uint, address[] memory) external view returns (uint[] memory);
}

contract BondingCalculatorD33D_USDC is Initializable, OwnableUpgradeable{

    address public D33D;
    address public USDC;
    IUNIPair public pair;
    IRouter public router;
    
    uint markdownPerc; //2 decimals 5000 for 50%
    
    function initialize( uint markdownPerc_, address admin_, IUNIPair _pair, 
        address _D33D, IRouter _router, address _USDC) external initializer{
        
        D33D = _D33D;
        USDC = _USDC;
        router = _router;
        markdownPerc = markdownPerc_;
        pair = _pair;

        __Ownable_init();

        transferOwnership(admin_);
    }

    function changeMarkdownPerc(uint newPerc_) external onlyOwner {
        markdownPerc = newPerc_;
    }

    function lpPrice(uint _amount) internal view returns (uint) {
        (uint reserve0, uint reserve1) = pair.getReserves();
        uint totalSupply_ = pair.totalSupply();

        if(pair.token0() != D33D) {
            (reserve0, reserve1) = (reserve1, reserve0);
        }

        //get d33d price in USDC
        address[] memory path = new address[](2);
        path[0] = D33D;
        path[1] = USDC;
        uint price_ = router.getAmountsOut(1e18, path)[1];

        uint total0 = _amount * reserve0 / totalSupply_;
        uint total1 = _amount * reserve1 / totalSupply_;

        return ((price_ * total0) + (total1 * 10 ** 18)) / 10 ** 6;

    }
    ///@return _value MarkdownPrice in usd (18 decimals)
    function valuation( address strategy_, uint amount_ ) external view returns ( uint _value ) {
        
        return lpPrice(amount_) * markdownPerc / 10000;
    }

    ///@return Mardown price of 1 token in USD (18 decimals)
    function markdown( address strategy_ ) external view returns ( uint ) {
        return lpPrice(1e18) * markdownPerc / 10000;
    }
}
