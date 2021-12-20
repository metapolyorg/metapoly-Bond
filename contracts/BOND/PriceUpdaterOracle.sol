pragma solidity 0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

interface IBond {
    function setPrice(uint) external ;
}

interface IERC20 {
    function transfer(address, uint) external;
}

contract PriceUpdater is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    address public bond;
    address public admin;
    address private oracle;
    uint private oracleFee;
    bytes32 private jobId; 

    string url;
    string path;
    int times;


    modifier onlyAdmin {
        require(msg.sender == admin, "Only Admin");
        _;
    }

    constructor(address _admin, address _oracle, bytes32 _jobId, uint _oracleFee) {
        setPublicChainlinkToken();

        admin = _admin;
        oracle = _oracle;
        jobId = _jobId;
        oracleFee = _oracleFee ;        
    }

    function updateOracleParams(address _oracle, bytes32 _jobId, uint _oracleFee) external onlyAdmin {
        oracle = _oracle;
        jobId = _jobId;
        oracleFee = _oracleFee ;
    }

    function updatePriceApi(address _bond, string memory _url, string memory _path, int _times) external onlyAdmin {
        bond = _bond;
        url = _url;
        path = _path;
        times = _times;
    }   

    function requestPriceUpdate() external {
        require(msg.sender == bond, "not authorised");
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);

        request.add("get", url);
        request.add("path", path);

        request.addInt("times", times);

        // request.addInt("times", int(10**18));
        sendChainlinkRequestTo(oracle, request, oracleFee);
    }

    ///@dev Used by oracle to update the floor price
    function fulfill(bytes32 _requestId, uint256 _priceInETH) external recordChainlinkFulfillment(_requestId) {
        IBond(bond).setPrice(_priceInETH);
    }

    function withdrawLINK(uint _amount) external onlyAdmin {
        IERC20(chainlinkTokenAddress()).transfer(admin, _amount);
    }


}