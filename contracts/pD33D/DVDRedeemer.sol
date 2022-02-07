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

    struct Term {
        uint amount;
        uint priceInDVD;
        uint interval;
    }

    struct TermVipDVD {
        uint amount;
        uint priceInVipDVD;
        uint interval;
    }

    Term[] public Terms;
    TermVipDVD[] public TermsVipDVD;

    IERC20 public DVD;
    IERC20 public VIPDVD;
    IERC20 public pD33D;

    function initialize(IERC20 _dvd, IERC20 _vipDvd, IERC20 _pd33d,
        uint[] memory _amount, uint[] memory _interval, uint[] memory _priceDvd, 
        uint[] memory _amountVipDVD, uint[] memory _intervalVipDvd, uint[] memory _priceVipDvd) external initializer {
        DVD = _dvd;
        VIPDVD = _vipDvd;
        pD33D = _pd33d;

        startTimestamp = block.timestamp;

        for(uint i=0; i < _amount.length; i++) {
            Terms.push(
                Term({
                    amount: _amount[i],
                    priceInDVD: _priceDvd[i] * 10**18,
                    interval: _interval[i]
                })
            );

            TermsVipDVD.push(
                TermVipDVD({
                    amount: _amountVipDVD[i],
                    priceInVipDVD: _priceVipDvd[i] * 10**18,
                    interval: _intervalVipDvd[i]
                })
            );

        }

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

    function calcpD33d(uint _dvdAmount) public view returns (uint pD33DAmt) {
        uint timeElapsed = block.timestamp - startTimestamp;

        Term[] memory info = Terms;
        for(uint i=0; i < info.length; i++) {
            if(info[i].amount != 0 && (pD33DClaimed <= info[i].amount && pD33DClaimed < info[i].interval)) {
                pD33DAmt = _dvdAmount * 1e18 / info[i].priceInDVD;
                i = info.length; //exit loop
            }
        }

        //pD33DAmt will be zero when `timeElapsed` is greater than final 
        if(pD33DAmt == 0) {
            // Until all pD33D redeemed
            pD33DAmt = _dvdAmount * 1e18 / info[info.length -1].priceInDVD;
        }
    }

    function calcForVipDVD(uint _vipDVDAmount) public view returns (uint pD33DAmt) {
        uint timeElapsed = block.timestamp - startTimestamp;

        TermVipDVD[] memory info = TermsVipDVD;
        for(uint i=0; i < info.length; i++) {
            if(info[i].amount != 0 && (pD33DClaimed <= info[i].amount && pD33DClaimed < info[i].interval)) {
                pD33DAmt = _vipDVDAmount * 1e18 / info[i].priceInVipDVD;
                i = info.length; //exit loop
            }
        }

        //pD33DAmt will be zero when `timeElapsed` is greater than final 
        if(pD33DAmt == 0) {
            // Until all pD33D redeemed
            pD33DAmt = _vipDVDAmount * 1e18 / info[info.length -1].priceInVipDVD;
        }
    }

    ///@dev setting _amount to 0 will delete/ignore that entry while calculating  
    ///@param _index Array index
    ///@param _amount pD33D claimed ceil
    ///@param _priceInDVD Price in DVD
    ///@param _interval Interval in seconds (ex for 1 week use 604800)
    function updateDVDTerms(uint _index, uint _amount, uint _priceInDVD, uint _interval) external onlyOwner {
        if(Terms.length <= _index) {
            require(_index == Terms.length, "Index mismatch"); //Using `require` instead of updating the `if`, to prevent it failing silently
            Terms.push(
                Term({
                    amount : _amount,
                    priceInDVD : _priceInDVD,
                    interval : _interval
                })
            );
        } else if(Terms.length > _index){
            Terms[_index] = Term({
                amount : _amount,
                priceInDVD : _priceInDVD,
                interval : _interval
            });
        }
    }

    function updateVipDVDTerms(uint _index, uint _amount, uint _priceInVipDVD, uint _interval) external onlyOwner {
        if(TermsVipDVD.length <= _index) {
            require(_index == TermsVipDVD.length, "Index mismatch"); //Using `require` instead of updating the `if`, to prevent it failing silently
            TermsVipDVD.push(
                TermVipDVD({
                    amount : _amount,
                    priceInVipDVD : _priceInVipDVD,
                    interval : _interval
                })
            );
        } else if(TermsVipDVD.length > _index){
            TermsVipDVD[_index] = TermVipDVD({
                amount : _amount,
                priceInVipDVD : _priceInVipDVD,
                interval : _interval
            });
        }
    }

    function withdrawPD33D(address _to, uint _amt) external onlyOwner {
        pD33D.safeTransfer(_to, _amt);
    }
}