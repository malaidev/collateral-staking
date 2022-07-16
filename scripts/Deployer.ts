import { IDeployConfig } from "./config/DeployConfig"
import { DeploymentHelper } from "./utils/DeploymentHelper"
import { ethers } from "hardhat"
import { Contract, Signer } from "ethers"

export class Deployer {
	config: IDeployConfig
	helper: DeploymentHelper
	deployer?: Signer

	collStakingManager?: Contract

	constructor(config: IDeployConfig) {
		this.config = config
		this.helper = new DeploymentHelper(config)
	}

	async run() {
		console.log("run()")
		this.deployer = (await ethers.getSigners())[0]

		this.collStakingManager = await this.helper.deployUpgradeableContractWithName(
			"CollStakingManager",
			"CollStakingManager",
			"setUp",
			this.config.treasuryAddress,
			this.config.dpxToken,
			this.config.gmxToken,
			this.config.dpxStakingRewards,
			this.config.gmxRewardRouterV2
		)
	}
}
