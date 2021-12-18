// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.7;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

interface IChainlink {
    function latestAnswer() external view returns (int256);
}

contract BondingCalculatorSAND is Initializable, OwnableUpgradeable{

    address public CESTA;
    IChainlink public oracleSand_USD;
    uint markdownPerc; //2 decimals 5000 for 50%
    function initialize( uint markdownPerc_, address admin_, IChainlink _oracleSand_USD) external initializer{
        markdownPerc = markdownPerc_;
        oracleSand_USD = oracleSand_USD;

        __Ownable_init();

        transferOwnership(admin_);
    }

    function changeMarkdownPerc(uint newPerc_) external onlyOwner {
        markdownPerc = newPerc_;
    }

    ///@return _value MarkdownPrice in usd (18 decimals)
    function valuation( address strategy_, uint amount_ ) external view returns ( uint _value ) {
        _value = (uint(oracleSand_USD.latestAnswer()) * amount_ * markdownPerc) / 10 ** 12;
    }

    ///@return Mardown price of 1 token in USD (18 decimals)
    function markdown( address strategy_ ) external view returns ( uint ) {
        return (uint(oracleSand_USD.latestAnswer()) * 1e18 * markdownPerc) / 10 ** 12;
    }
}