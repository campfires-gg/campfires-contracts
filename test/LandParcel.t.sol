/* solhint-disable no-console */
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "account-abstraction/core/EntryPoint.sol";

import "erc6551/ERC6551Registry.sol";
import "erc6551/interfaces/IERC6551Account.sol";

import {Account as TokenboundAccount} from "tokenbound/Account.sol";
import {AccountGuardian} from "tokenbound/AccountGuardian.sol";

import {LandParcelMock} from "../src/mock/LandParcelMock.sol";
import {QuestRewardMock} from "../src/mock/QuestRewardMock.sol";
import {ExperiencePointMock} from "../src/mock/ExperiencePointMock.sol";

contract LandParcelTest is Test {
    address public verifier;

    // eip6551
    TokenboundAccount public implementation;
    AccountGuardian public guardian;
    ERC6551Registry public registry;
    IEntryPoint public entryPoint;

    LandParcelMock public landParcel;
    ExperiencePointMock public experiencePoint;
    QuestRewardMock public questReward;

    function setUp() public {
        uint256 privateKey = 0x1010101010101010101010101010101010101010101010101010101010101010;
        verifier = vm.addr(privateKey);

        // eip6551
        entryPoint = new EntryPoint();
        guardian = new AccountGuardian();
        implementation = new TokenboundAccount(
            address(guardian),
            address(entryPoint)
        );
        registry = new ERC6551Registry();

        experiencePoint = new ExperiencePointMock();
        questReward = new QuestRewardMock(
            verifier,
            address(experiencePoint)
        );
        landParcel = new LandParcelMock(
            address(experiencePoint),
            address(implementation),
            address(registry)
        );

        experiencePoint.setLandParcel(address(landParcel));
        experiencePoint.setQuestReward(address(questReward));
    }

    function testNothing() public {
        address user = vm.addr(1);
        uint256 tokenId = 1; // erc721a land parcel token bound account

        // owns multiple objects
        landParcel.mint(user, 1);
        assertEq(landParcel.balanceOf(user), 1);

        address computedAccountInstance = registry.account(
            address(implementation),
            block.chainid,
            address(landParcel),
            tokenId,
            0
        );
        console.log(computedAccountInstance);

        questReward.mint(computedAccountInstance, 1, 5);
        assertEq(questReward.balanceOf(computedAccountInstance, 1), 5);

        questReward.mint(computedAccountInstance, 2, 15);
        assertEq(questReward.balanceOf(computedAccountInstance, 2), 15);

        questReward.mint(computedAccountInstance, 3, 10);
        assertEq(questReward.balanceOf(computedAccountInstance, 3), 10);

        address accountAddress = registry.createAccount(
            address(implementation),
            block.chainid,
            address(landParcel),
            tokenId,
            0,
            ""
        );
        console.log(accountAddress);
        TokenboundAccount account = TokenboundAccount(payable(accountAddress));
        console.log(address(account));

        bytes memory erc721TransferCall = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256,uint256,bytes)",
            accountAddress,
            user,
            1,
            1,
            ""
        );

        vm.prank(user);
        account.executeCall(
            payable(address(questReward)),
            0,
            erc721TransferCall
        );

        assertEq(questReward.balanceOf(accountAddress, 1), 4);
        assertEq(questReward.balanceOf(user, 1), 1);
    }

    function testClaim() public {
        address user = vm.addr(0x002);
        console.log(user);

        experiencePoint.mint(user, 20_000);
        assertEq(experiencePoint.balanceOf(user), 20_000);

        vm.prank(user);
        (uint256 tokenId, address accountAddress) = landParcel.claim();

        assertEq(landParcel.balanceOf(user), 1);
        assertEq(
            registry.account(
                address(implementation),
                block.chainid,
                address(landParcel),
                tokenId,
                0
            ),
            accountAddress
        );
    }
}
