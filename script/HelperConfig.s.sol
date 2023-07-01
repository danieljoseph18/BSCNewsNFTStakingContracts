// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {MockToken} from "../src/mocks/MockToken.sol";
import {MockNft} from "../src/mocks/MockNft.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address nftCollection;
        address rewardToken;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig public config;

    constructor() {
        if (block.chainid == 11155111) {
            config = getSepoliaConfig();
        } else {
            config = getAnvilConfig(DEFAULT_ANVIL_KEY);
        }
    }
    //If on Anvil we need Mocks
    // Need Mock NFT and Mock ERC20 to deploy staking contract

    function getAnvilConfig(uint256 deployerKey) public returns (NetworkConfig memory) {
        vm.startBroadcast(deployerKey);
        MockNft nftCollection = new MockNft();
        MockToken rewardToken = new MockToken();
        vm.stopBroadcast();
        return NetworkConfig({
            nftCollection: address(nftCollection),
            rewardToken: address(rewardToken),
            deployerKey: DEFAULT_ANVIL_KEY
        });
    }
    // Deploy Mocks to Sepolia anyway

    function getSepoliaConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast();
        MockNft nftCollection = new MockNft();
        MockToken rewardToken = new MockToken();
        vm.stopBroadcast();
        return NetworkConfig({
            nftCollection: address(nftCollection),
            rewardToken: address(rewardToken),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }
}
