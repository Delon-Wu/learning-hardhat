const fs = require("fs");
const path = require("path");
const { ethers, upgrades } = require("hardhat")

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log("=== 开始升级 NFT 合约 ===");
  console.log("部署者地址:", deployer);

  // ❌ 问题 1: hardhat-deploy 不支持 upgrades 参数
  // ✅ 解决方案：使用 hardhat-deploy 的方式或 @openzeppelin/hardhat-upgrades

  // 方案 A: 使用 hardhat-deploy 原生方式（推荐）
  // ===========================================

  // 1. 读取之前缓存的代理地址
  const cachePath = path.resolve(__dirname, "./.cache/proxyAuctionNFT.json");
  
  let existingProxyAddress;
  try {
    const cacheData = JSON.parse(fs.readFileSync(cachePath, "utf8"));
    existingProxyAddress = cacheData.proxyAddress;
    console.log("从缓存读取代理地址:", existingProxyAddress);
  } catch (error) {
    console.error("❌ 无法读取代理地址缓存");
    throw new Error("请先运行初始部署脚本");
  }

  // 2. 部署新的实现合约 V2
  const nftV2Implementation = await deploy("AuctionNFTV2", {
    from: deployer,
    args: [], // UUPS 合约的 constructor 通常为空
    log: true,
    // ✅ 添加唯一标识避免重复部署
    skipIfAlreadyDeployed: false, // 每次都部署新实现
  });

  console.log("AuctionNFTV2 新实现合约地址:", nftV2Implementation.address);

  // 3. 通过代理调用 upgradeTo
  const signer = await ethers.getSigner(deployer);
  
  // ✅ 解决方案：直接通过代理合约调用 upgradeToAndCall
  const AuctionNFTV2 = await ethers.getContractFactory("AuctionNFTV2", signer);
  const proxyContract = await upgrades.upgradeProxy(existingProxyAddress, AuctionNFTV2);

  console.log("正在升级代理合约...");
  await proxyContract.waitForDeployment();
  console.log("✅ 合约升级成功!");

  // 4. 验证升级
  // const version = await proxyContract.version();
  // console.log("当前版本:", version);

  // 5. 保存升级后的信息
  const artifact = await deployments.getArtifact("AuctionNFTV2");
  const storePath = path.resolve(__dirname, "./.cache/proxyAuctionNFTUpgraded.json");
  
  fs.writeFileSync(
    storePath,
    JSON.stringify(
      {
        proxyAddress: existingProxyAddress,
        implAddress: nftV2Implementation.address,
        abi: artifact.abi,
        upgradedAt: new Date().toISOString(),
      },
      null,
      2
    )
  );

  console.log("升级信息已保存到:", storePath);
};

module.exports.tags = ["NFTUpgrade"];
module.exports.dependencies = ["NFTDeploy"]; // 确保先运行初始部署
