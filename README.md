# Simple Reward for Miletus Protocol

## Overview
This is a simple reward distributor contract for Miletus Protocol. This simple example assumes that fees generated by Miletus Protocol are sent to RewardDistributor and distributed to token stakers.  

## Step-by-step description

1. A user calls `stake()` to stake tokens (ex: Miletus Token)
4. Miletus admin or feeSharing smart contract will send reward tokens to the rewardDistributor contract by calling `distributeReward()`.
5. Reward token will be distributed to each staker based on the amount of tokens they have staked.
    - `reward for each staker = total reward amount * ( balanceOf[address] / totalSupply )`
    - `total reward amount`: reward token amount sent to the rewardDistributor contract by distributeReward()
    - `balanceOf[address]`: a staker's token staking balance
    - `totalSupply`: total amount of Miletus Tokens staked
6. Ater 90 days, when `block.timestamp > lockTime[msg.sender]`, the user can call `unstake()`.
    - `unstake()` will unstake both Miletus tokens and rewards.
    - `unstake()` will reset the lockTime and the user should have to stake() again and also wait for 90 days again to interact with the contract.
    - `withdrawReward()`: will only withdraw rewards. This does NOT reset the lockTime.
7. `stake()` always resets the `lockTime`.

## To-Dos
- [x] Survey GMX Contracts (reward distributor, tracker and router)
- [x] RewardDistributor Contract
- [x] RewardDistributor Unit Tests
- [x] RewardTracker Contract
- [ ] RewardTracker Unit Tests

## Survey on GMX RewardDistributor and RewardTracker

![GMX Architecture](https://github.com/gusiri/simple-reward/blob/master/doc/images/GmxRewardTracker.svg)

## References

### GMX Smart Contracts and Architecture

[https://rileygmi.substack.com/p/gmx?utm_source=substack&utm_medium=email&utm_content=share](https://rileygmi.substack.com/p/gmx?utm_source=substack&utm_medium=email&utm_content=share)

[https://liamhieuvu.com/how-gmx-limit-order-and-long-short-work](https://liamhieuvu.com/how-gmx-limit-order-and-long-short-work)

[https://medium.com/@STFX_IO/gmx-technical-series-demistifying-gmxs-rewards-programs-part-4-87c190655f50](https://medium.com/@STFX_IO/gmx-technical-series-demistifying-gmxs-rewards-programs-part-4-87c190655f50)

[https://medium.com/cwallet/exploring-gmx-multi-chain-decentralized-spot-and-perpetual-exchange-459cb82aa0c1](https://medium.com/cwallet/exploring-gmx-multi-chain-decentralized-spot-and-perpetual-exchange-459cb82aa0c1)

[https://medium.com/stakingbits/guide-to-gmx-and-glp-decentralized-crypto-exchange-cc35766a0164](https://medium.com/stakingbits/guide-to-gmx-and-glp-decentralized-crypto-exchange-cc35766a0164)

[https://gmxio.gitbook.io/gmx/rewards](https://gmxio.gitbook.io/gmx/rewards)

[https://medium.com/coinmonks/gmx-a-brief-explanation-a1f6ade01b04](https://medium.com/coinmonks/gmx-a-brief-explanation-a1f6ade01b04)

[https://gambitprotocol.medium.com/gmx-tokenomics-pt-i-f2f100a0da0f](https://gambitprotocol.medium.com/gmx-tokenomics-pt-i-f2f100a0da0f)


## Getting Started

Clone this repo and 

```sh
forge test
```

## Foundry

This project uses [Foundry](https://getfoundry.sh). See the [book](https://book.getfoundry.sh/getting-started/installation.html) for instructions on how to install and use Foundry.
