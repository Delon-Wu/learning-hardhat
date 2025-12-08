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
    mapping(address => uint256) private _balances;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init("MemeToken", "MMTK");
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        
    }
    
    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override {}

    // ├─ 交易税模块
    // │  ├─ _transfer override
    // │  ├─ 税费计算逻辑
    // │  └─ 白名单管理

    function _transfer(address from, address to, uint256 amount) public override(ERC20Upgradeable) returns(bool) {
        uint256 
        transfer();
        return true;
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
