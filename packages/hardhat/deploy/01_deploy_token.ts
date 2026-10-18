import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const deployToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  await hre.deployments.deploy("FJYToken", { from: deployer, args: [], log: true, autoMine: true });
};

export default deployToken;
deployToken.tags = ["TOKENFJY202430550391"];
