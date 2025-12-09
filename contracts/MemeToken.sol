// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract MemeToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    ERC20BurnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    address public marketWallet;
    address public developmentWallet;
    address public liquidityWallet;

    uint256 public buyMarketTax;
    uint256 public buyDevelopmentTax;
    uint256 public buyLiquidityTax;

    uint256 public sellMarketTax;
    uint256 public sellDevelopmentTax;
    uint256 public sellLiquidityTax;

    uint256 public constant MAX_TAXT_RAGE = 1500;

    mapping(address => bool) public isExcludedFromFee;

    mapping(address => bool) public automatedMarketMakerPairs; // DEX 交易对地址

    bool private inSwap;
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _marketWallet,
        address _developmentWallet,
        address _liquidityWallet
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __ReentrancyGuard_init();

        require(_marketWallet != address(0), "Market Wallet cannot be zero");
        require(_developmentWallet != address(0), "Development Wallet cannot be zero");
        require(_liquidityWallet != address(0), "Liquidity Wallet cannot be zero");
        marketWallet = _marketWallet;
        developmentWallet = _developmentWallet;
        liquidityWallet = _liquidityWallet;

        buyMarketTax = 200;
        buyDevelopmentTax = 100;
        buyLiquidityTax = 200;

        sellMarketTax = 400;
        sellDevelopmentTax = 200;
        sellLiquidityTax = 400;

        isExcludedFromFee[msg.sender] = true;
        isExcludedFromFee[address(this)] = true; // ???
        isExcludedFromFee[marketWallet] = true;
        isExcludedFromFee[developmentWallet] = true;
        isExcludedFromFee[liquidityWallet] = true;

        _mint(msg.sender, initialSupply);
    }
    
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    // ├─ 交易税模块
    // │  ├─ _transfer override
    // │  ├─ 税费计算逻辑
    // │  └─ 白名单管理

    function _transfer(address from, address to, uint256 amount) internal nonReentrant override(ERC20Upgradeable) {
        if (from == address(0) || to == address(0)) {
            super._transfer(from, to, amount);
            return;
        }
        // 在交换中，避免递归收税
        if (inSwap) {
            super._transfer(from, to, amount);
            return;
        }

        bool takeFee = true;
        if (isExcludedFromFee[from] || isExcludedFromFee[to]) {
            takeFee = false;// 白名单
        }
        if (!automatedMarketMakerPairs[from] && !automatedMarketMakerPairs[to]) {
            takeFee = false;// 普通用户间转账
        }

        if (takeFee) {
            bool isBuy = automatedMarketMakerPairs[from];
            bool isSell = automatedMarketMakerPairs[to];
            if (isBuy) {

            } else if (isSell) {

            }
        }
    }


    // ├─ Uniswap 集成
    // │  ├─ Router 接口
    // │  ├─ Pair 地址记录
    // │  └─ 自动做市商检测

    // └─ 流动性管理
    //    ├─ addLiquidityETH
    //    ├─ removeLiquidityETH
    //    └─ LP Token 处理
}
