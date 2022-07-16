export interface IDeployConfig {
  outputFile: string
  TX_CONFIRMATIONS: number

  treasuryAddress: string,
  dpxToken: string,
  gmxToken: string,
  dpxStakingRewards: string,
  gmxRewardRouterV2: string
}
