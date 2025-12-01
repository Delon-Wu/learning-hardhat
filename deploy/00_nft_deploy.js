const fs = require("fs");
const path = require("path");

module.exports = async ({ getNamedAccounts, deployments, ethers, upgrades }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const deployerSigner = await ethers.getSigner(deployer);

  console.log("Deploying AuctionNFT with account:", deployer);

  const AuctionNFT = await ethers.getContractFactory("AuctionNFT", deployerSigner);

  // 部署代理合约
  const proxy = await upgrades.deployProxy(
    AuctionNFT,
    [],
    {
      initializer: "initialize",
      kind: "uups",
      txOerrides: {
        gasLimit: 10_000_000
      }
    }
  );

  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();

  const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress)
  console.log("AuctionNFT deployed to:", implementationAddress);

  const artifact = await deployments.getArtifact("AuctionNFT");

  const storePath = path.resolve(__dirname, "./.cache/proxyAuctionNFT.json");
  fs.writeFileSync(
    storePath,
    JSON.stringify({
      proxyAddress: proxyAddress,
      implAddress: implementationAddress,
      abi: artifact.abi,
    }, null, 2)
  );

  // 可选：验证合约（如果在测试网）
  // await run("verify:verify", {
  //   address: nft.address,
  //   constructorArguments: [],
  // });
};
module.exports.tags = ["AuctionNFT"];
