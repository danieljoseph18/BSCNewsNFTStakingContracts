//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {BSCNewsNFTStaking} from "../src/BSCNewsNFTStaking.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract StartStakingPeriod is Script {
    function startStakingPeriod(address stakingContractAddress, uint256 amountInWei, uint256 durationInSeconds)
        public
    {
        HelperConfig config = new HelperConfig();
        (,, uint256 deployerKey) = config.config();
        vm.startBroadcast(deployerKey);
        BSCNewsNFTStaking staking = BSCNewsNFTStaking(stakingContractAddress);
        staking.startStakingPeriod(amountInWei, durationInSeconds);
        vm.stopBroadcast();
        console.log("Staking period started");
    }

    function run(address stakingContractAddress, uint256 amountInWei, uint256 durationInSeconds) external {
        startStakingPeriod(stakingContractAddress, amountInWei, durationInSeconds);
    }
}
