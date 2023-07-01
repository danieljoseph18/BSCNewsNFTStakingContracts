// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BSCNewsNFTStaking} from "../src/BSCNewsNFTStaking.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployNFTStaking is Script {
    function run() external returns (BSCNewsNFTStaking, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address nftCollection, address rewardToken, uint256 deployerKey) = config.config();
        vm.startBroadcast(deployerKey);
        BSCNewsNFTStaking staking = new BSCNewsNFTStaking(nftCollection, rewardToken);
        vm.stopBroadcast();
        return (staking, config);
    }
}
