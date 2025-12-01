module.exports = async ({ getNamedAccounts, deployments, ethers, upgrades }) => {
  const { deployer } = await getNamedAccounts();
  const deployerSigner = await ethers.getSigner(deployer);

  console.log("Deploying NFTMarketplace with account:", deployer);

  // 获取合约工厂
  const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace", deployerSigner);
  
  // 部署可升级合约
  console.log("Deploying proxy...");
  const marketplace = await upgrades.deployProxy(
    NFTMarketplace,
    [], // 初始化参数
    { 
      initializer: "initialize",
      kind: 'uups',
      txOverrides: {
        gasLimit: 10000000
      }
    }
  );

  await marketplace.waitForDeployment();
  const proxyAddress = await marketplace.getAddress();
  
  console.log("NFTMarketplace Proxy deployed to:", proxyAddress);
  
  // 获取实现合约地址
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
  console.log("Implementation contract address:", implementationAddress);
  
  // 保存部署信息
  const artifact = await deployments.getArtifact('NFTMarketplace');
  await deployments.save('NFTMarketplace', {
    address: proxyAddress,
    abi: artifact.abi
  });
};
module.exports.tags = ['NFTMarketplace'];