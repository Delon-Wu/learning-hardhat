// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
// import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTMarketplace is 
    Initializable, 
    OwnableUpgradeable, 
    UUPSUpgradeable, 
    ReentrancyGuardUpgradeable 
{
    // 拍卖结构
    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
        address bidToken; // 出价代币地址 (address(0) 表示ETH)
        bool settled;
    }

    // Chainlink 价格预言机
    AggregatorV3Interface internal ethUsdPriceFeed;
    mapping(address => AggregatorV3Interface) public erc20PriceFeeds;
    
    // 支持的ERC20代币
    mapping(address => bool) public supportedTokens;
    
    // 拍卖映射
    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCount;
    
    // 手续费比例 (基础点，100 = 1%)
    uint256 public feePercentage;
    address public feeWallet;
    
    // 事件
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime,
        address bidToken
    );
    
    event NewBid(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        address token
    );
    
    event AuctionSettled(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 amount
    );
    
    event AuctionCancelled(uint256 indexed auctionId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        // 初始化ETH/USD价格预言机 (主网地址)
        ethUsdPriceFeed = AggregatorV3Interface(0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        
        feePercentage = 250; // 2.5%
        feeWallet = msg.sender;
        auctionCount = 1;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    // 设置ERC20代币的价格预言机
    function setERC20PriceFeed(address token, address priceFeed) external onlyOwner {
        erc20PriceFeeds[token] = AggregatorV3Interface(priceFeed);
        supportedTokens[token] = true;
    }

    // 设置手续费
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 1000, "Fee too high"); // 最大10%
        feePercentage = _feePercentage;
    }

    // 获取最新价格
    function getLatestPrice(AggregatorV3Interface priceFeed) internal view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    // 获取代币的USD价格
    function getTokenPrice(address token) public view returns (uint256) {
        if (token == address(0)) {
            // ETH价格
            return getLatestPrice(ethUsdPriceFeed);
        } else {
            require(supportedTokens[token], "Token not supported");
            return getLatestPrice(erc20PriceFeeds[token]);
        }
    }

    // 计算USD价值
    function calculateUsdValue(uint256 amount, address token) public view returns (uint256) {
        uint256 price = getTokenPrice(token);
        // uint8 decimals = token == address(0) ? 18 : IERC20Upgradeable(token).decimals();
        uint8 decimals = 18;
        
        // 调整精度计算
        if (decimals < 18) {
            amount = amount * (10 ** (18 - decimals));
        } else if (decimals > 18) {
            amount = amount / (10 ** (decimals - 18));
        }
        
        return (amount * price) / 1e8; // Chainlink价格有8位小数
    }

    // 创建拍卖
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration,
        address bidToken // address(0) for ETH, otherwise ERC20 address
    ) external {
        require(duration >= 1 hours && duration <= 30 days, "Invalid duration");
        require(reservePrice >= startPrice, "Reserve price must be >= start price");
        
        if (bidToken != address(0)) {
            require(supportedTokens[bidToken], "Bid token not supported");
        }

        // 转移NFT到合约
        IERC721Upgradeable(nftContract).transferFrom(msg.sender, address(this), tokenId);

        uint256 startTime = block.timestamp;
        uint256 endTime = startTime + duration;

        auctions[auctionCount] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            reservePrice: reservePrice,
            startTime: startTime,
            endTime: endTime,
            highestBidder: address(0),
            highestBid: 0,
            bidToken: bidToken,
            settled: false
        });

        emit AuctionCreated(
            auctionCount,
            nftContract,
            tokenId,
            msg.sender,
            startPrice,
            reservePrice,
            startTime,
            endTime,
            bidToken
        );

        auctionCount++;
    }

    // 出价 (ETH)
    function bidWithETH(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.bidToken == address(0), "This auction requires ERC20 tokens");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(!auction.settled, "Auction already settled");

        uint256 usdValue = calculateUsdValue(msg.value, address(0));
        uint256 minUsdValue = calculateUsdValue(auction.startPrice, address(0));
        
        require(usdValue >= minUsdValue, "Bid too low");
        require(
            usdValue > calculateUsdValue(auction.highestBid, address(0)),
            "Bid must be higher than current bid"
        );

        // 退回前一个最高出价者的ETH
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit NewBid(auctionId, msg.sender, msg.value, address(0));
    }

    // 出价 (ERC20)
    function bidWithERC20(uint256 auctionId, uint256 amount) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.bidToken != address(0), "This auction requires ETH");
        require(block.timestamp >= auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(!auction.settled, "Auction already settled");

        uint256 usdValue = calculateUsdValue(amount, auction.bidToken);
        uint256 minUsdValue = calculateUsdValue(auction.startPrice, auction.bidToken);
        
        require(usdValue >= minUsdValue, "Bid too low");
        require(
            usdValue > calculateUsdValue(auction.highestBid, auction.bidToken),
            "Bid must be higher than current bid"
        );

        // 转移代币到合约
        IERC20Upgradeable(auction.bidToken).transferFrom(msg.sender, address(this), amount);

        // 退回前一个最高出价者的代币
        if (auction.highestBidder != address(0)) {
            IERC20Upgradeable(auction.bidToken).transfer(auction.highestBidder, auction.highestBid);
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = amount;

        emit NewBid(auctionId, msg.sender, amount, auction.bidToken);
    }

    // 结算拍卖
    function settleAuction(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(block.timestamp > auction.endTime, "Auction not ended");
        require(!auction.settled, "Auction already settled");
        require(
            msg.sender == auction.seller || msg.sender == auction.highestBidder,
            "Not authorized"
        );

        auction.settled = true;

        if (auction.highestBidder != address(0) && auction.highestBid >= auction.reservePrice) {
            // 成功售出
            uint256 fee = (auction.highestBid * feePercentage) / 10000;
            uint256 sellerAmount = auction.highestBid - fee;

            if (auction.bidToken == address(0)) {
                // ETH支付
                payable(auction.seller).transfer(sellerAmount);
                payable(feeWallet).transfer(fee);
            } else {
                // ERC20支付
                IERC20Upgradeable(auction.bidToken).transfer(auction.seller, sellerAmount);
                IERC20Upgradeable(auction.bidToken).transfer(feeWallet, fee);
            }

            // 转移NFT给获胜者
            IERC721Upgradeable(auction.nftContract).transferFrom(
                address(this),
                auction.highestBidder,
                auction.tokenId
            );

            emit AuctionSettled(auctionId, auction.highestBidder, auction.highestBid);
        } else {
            // 未达到保留价，退回NFT给卖家
            IERC721Upgradeable(auction.nftContract).transferFrom(
                address(this),
                auction.seller,
                auction.tokenId
            );

            emit AuctionCancelled(auctionId);
        }
    }

    // 获取拍卖信息
    function getAuction(uint256 auctionId) external view returns (Auction memory) {
        return auctions[auctionId];
    }

    // 获取当前ETH价格
    function getETHPrice() external view returns (uint256) {
        return getTokenPrice(address(0));
    }

    // 紧急取消拍卖 (仅限所有者)
    function emergencyCancelAuction(uint256 auctionId) external onlyOwner {
        Auction storage auction = auctions[auctionId];
        require(!auction.settled, "Auction already settled");

        auction.settled = true;

        // 退回NFT给卖家
        IERC721Upgradeable(auction.nftContract).transferFrom(
            address(this),
            auction.seller,
            auction.tokenId
        );

        // 退回当前最高出价
        if (auction.highestBidder != address(0)) {
            if (auction.bidToken == address(0)) {
                payable(auction.highestBidder).transfer(auction.highestBid);
            } else {
                IERC20Upgradeable(auction.bidToken).transfer(auction.highestBidder, auction.highestBid);
            }
        }

        emit AuctionCancelled(auctionId);
    }
}