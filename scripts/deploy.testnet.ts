import { IDeployConfig } from "./config/DeployConfig"
import { Deployer } from "./Deployer"
import { DeploymentHelper } from "./utils/DeploymentHelper"
import { ethers } from "hardhat"

const config: IDeployConfig = {
	outputFile: "./testnet_deployments.json",
	TX_CONFIRMATIONS: 1,
	treasuryAddress: "",
	dpxToken: "",
	gmxToken: "",
	dpxStakingRewards: "",
	gmxRewardRouterV2: "",
}

async function main() {
	const helper = new DeploymentHelper(config)

	config.treasuryAddress = (await ethers.getSigners())[0].address

	config.dpxToken = (await helper.deployContractByName("MockERC20", "DPX", "DPX", "DPX")).address
	config.gmxToken = (await helper.deployContractByName("MockERC20", "GMX", "GMX", "GMX")).address

	config.dpxStakingRewards = 
		(await helper.deployContractByName("MockDpxStakingRewards", "DpxStakingRewards", config.dpxToken)).address

	config.gmxRewardRouterV2 = 
		(await helper.deployContractByName("MockGmxRewardRouterV2", "GmxRewardRouterV2", config.gmxToken)).address

	await new Deployer(config).run()
}

main().catch(error => {
	console.error(error)
	process.exitCode = 1
})
