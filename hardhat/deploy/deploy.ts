import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy, getOrNull } = hre.deployments;

  // Check if contract was previously deployed
  const existingDeployment = await getOrNull("BlanqueoConfidentialERC20");
  const isNewDeployment = !existingDeployment;

  const deployed = await deploy("BlanqueoConfidentialERC20", {
    from: deployer,
    args: [deployer],
    log: true,
  });

  console.log(`BlanqueoConfidentialERC20 contract: `, deployed.address);
  if (isNewDeployment) {
    const signers = await hre.ethers.getSigners();
    const alice = signers[0];
    const mintAmount = 10_000n;
    const tokenFactory = await hre.ethers.getContractFactory("BlanqueoConfidentialERC20");
    const token = tokenFactory.attach(deployed.address);
    const mintTx = await token.mint(alice, mintAmount);
    await mintTx.wait();
    console.log(`Alice minted ${mintAmount} tokens to herself`);
  }
};
export default func;
func.id = "deploy_blanqueoConfidentialERC20"; // id required to prevent reexecution
func.tags = ["BlanqueoConfidentialERC20"];
