import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const ARBITER = "0x96f90Fc02d300188EB5Eb2bBB84Aa1616e015918";
const deployEscrow: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  await hre.deployments.deploy("Escrow", { from: deployer, args: [ARBITER], log: true, autoMine: true });
};

export default deployEscrow;
deployEscrow.tags = ["EscrowFJY202430550391"];
