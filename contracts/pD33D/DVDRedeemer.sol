pragma solidity 0.8.7;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IERC20 is IERC20Upgradeable {
    function burnFrom(address, uint) external;
    function withdraw(uint _shares) external; //vip dvd
    function burn(uint _shares) external;
}

contract DvDRedeemer is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20;

    uint pD33DClaimed;
    uint startTimestamp;

    IERC20 public DVD;
    IERC20 public VIPDVD;
    IERC20 public pD33D;

    function initialize(IERC20 _dvd, IERC20 _vipDvd, IERC20 _pd33d) external initializer {
        DVD = _dvd;
        VIPDVD = _vipDvd;
        pD33D = _pd33d;

        startTimestamp = block.timestamp;

        __Ownable_init();
    }

    function redeemDVD(uint _dvdAmount) external {
        uint pD33dAmt = calcpD33d(_dvdAmount);

        pD33DClaimed += pD33dAmt;

        DVD.burnFrom(msg.sender, _dvdAmount);

        pD33D.safeTransfer(msg.sender, pD33dAmt);

    }

    function redeemVipDVD(uint _vipDVDAmount) external {
        uint pD33dAmt = calcForVipDVD(_vipDVDAmount);

        pD33DClaimed += pD33dAmt;

        VIPDVD.safeTransferFrom(msg.sender, address(this), _vipDVDAmount);
        VIPDVD.withdraw(_vipDVDAmount);

        uint _dvdAmount = DVD.balanceOf(address(this));

        DVD.burn(_dvdAmount);

        pD33D.safeTransfer(msg.sender, pD33dAmt);
    }

    function calcpD33d(uint _dvdAmount) public view returns (uint) {
        uint timeElapsed = block.timestamp - startTimestamp;
        uint priceInDVD; 
        if(pD33DClaimed <= 500_000 * 1e18 && timeElapsed < 1 weeks) {
            priceInDVD = 10 * 1e18;
        } else if (pD33DClaimed <= 1_000_000 * 1e18 && timeElapsed < 2 weeks) {
            priceInDVD = 12 * 1e18;
        } else if (pD33DClaimed <= 1_500_000 * 1e18 && timeElapsed < 3 weeks) {
            priceInDVD = 14 * 1e18;
        } else if (pD33DClaimed <= 2_000_000 * 1e18 && timeElapsed < 4 weeks) {
            priceInDVD = 16 * 1e18;
        } else {
            priceInDVD = 18 * 1e18;
        }

        return _dvdAmount * 1e18 / priceInDVD;
    }

    function calcForVipDVD(uint _vipDVDAmount) public view returns (uint) {
        uint timeElapsed = block.timestamp - startTimestamp;
        uint priceInVipDVD;
        if(pD33DClaimed <= 500_000 * 1e18 && timeElapsed < 1 weeks) {
            priceInVipDVD = 5 * 1e18;
        } else if (pD33DClaimed <= 1_000_000 * 1e18 && timeElapsed < 2 weeks) {
            priceInVipDVD = 6 * 1e18;
        } else if (pD33DClaimed <= 1_500_000 * 1e18 && timeElapsed < 3 weeks) {
            priceInVipDVD = 7 * 1e18;
        } else if (pD33DClaimed <= 2_000_000 * 1e18 && timeElapsed < 4 weeks) {
            priceInVipDVD = 8 * 1e18;
        } else {
            priceInVipDVD = 9 * 1e18;
        }

        return _vipDVDAmount * 1e18 / priceInVipDVD;
    }

    function withdrawPD33D(address _to, uint _amt) external onlyOwner {
        pD33D.safeTransfer(_to, _amt);
    }
}