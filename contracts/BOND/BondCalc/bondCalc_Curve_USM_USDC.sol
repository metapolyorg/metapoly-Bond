pragma solidity 0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface ICurvePool {
    function calc_withdraw_one_coin(uint amount_, int128 index_) external view returns (uint);
}
contract bondCalc_Curve_USM_USDC is Initializable, OwnableUpgradeable {

    ICurvePool public CurvePool ;
    uint public markdownPerc; //2 decimals 5000 for 50%
    int128 index;

    ///@param _index USDC index in curvepool
    function initialize(int128 _index) external initializer {
        __Ownable_init();

        index = _index;
    }

    ///@dev returns price in USDC;
    ///@notice amount of lp token
    ///@return USDC amount for the given amount_ of lpTokens (18 decimals)
    function getPrice(uint amount_) internal view returns (uint) {
       return CurvePool.calc_withdraw_one_coin(amount_, index) * 10 ** 12;
    }

    function valuation( address strategy_, uint amount_ ) external view returns ( uint _value ) {
        return getPrice(amount_) * markdownPerc / 10000;
    }

    ///@return Mardown price of 1 token in USD (18 decimals)
    function markdown( address strategy_ ) external view returns ( uint ) {
        return getPrice(1e18) * markdownPerc / 10000;
    }

    ///@return Price of LP token in USD (18 decimals)
    function getRawPrice() external view returns (uint) {
        return getPrice(1e18);
    }

    ///@param newPerc_ markdown percentage (2 deccimals)
    function changeMarkdownPerc(uint newPerc_) external onlyOwner {
        markdownPerc = newPerc_;
    }
}