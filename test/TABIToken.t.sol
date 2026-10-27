// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TABIToken} from "../src/TABIToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {UUPSUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title TABITokenTest
 * @dev Test contract for TABIToken with upgradeable proxy pattern
 * @notice Contains all test cases for the TABIToken contract functionality
 * @author TABI Team
 */
contract TABITokenTest is Test {
    // Test Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event Paused(address account);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    // Constants
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // Test accounts
    address public admin;
    address public minter;
    address public pauser;
    address public user1;
    address public user2;

    // Contract instances
    TABIToken public implementation;
    ERC1967Proxy public proxy;
    TABIToken public token;

    /**
     * @dev Setup function called before each test
     */
    function setUp() public {
        // Setup test accounts
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy implementation contract
        implementation = new TABIToken();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(TABIToken.initialize.selector, admin);

        // Deploy proxy contract
        proxy = new ERC1967Proxy(address(implementation), initData);

        // Create token instance pointing to proxy
        token = TABIToken(address(proxy));
    }

    /**
     * @dev Test suite for initialization and proxy setup
     */
    function test_ProxyInitialization() public view {
        // Test token details
        assertEq(token.name(), "TABI");
        assertEq(token.symbol(), "TABI");
        assertEq(token.decimals(), 18);

        // Test roles
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, admin));
        assertTrue(token.hasRole(MINTER_ROLE, admin));
        assertTrue(token.hasRole(PAUSER_ROLE, admin));

        // Verify implementation
        assertEq(address(implementation), _getImplementation());
    }

    /**
     * @dev initialize must reject a zero admin address: with `initialize(0)`,
     * DEFAULT_ADMIN/MINTER/PAUSER roles would land on address(0) and all
     * privileged operations would be permanently bricked.
     */
    function test_InitializeRevertsForZeroAdmin() public {
        TABIToken freshImplementation = new TABIToken();
        bytes memory badInitData = abi.encodeWithSelector(TABIToken.initialize.selector, address(0));

        // Deploying a proxy with the invalid initData must revert.
        vm.expectRevert();
        new ERC1967Proxy(address(freshImplementation), badInitData);

        // Even direct initialization on a live proxy copy must revert.
        TABIToken direct = new TABIToken();
        vm.expectRevert();
        direct.initialize(address(0));
    }

    /**
     * @dev initialize is guarded by `initializer`: a second call after the
     * initial setup must always revert, including through an upgrade call
     * passing non-empty initData targeting address(this).
     */
    function test_ReInitializationSecretAttemptsRevert() public {
        vm.expectRevert();
        token.initialize(makeAddr("newAdmin"));
    }

    /**
     * @dev Test suite for contract upgradeability
     */
    function test_Upgradeability() public {
        // Deploy new implementation
        TABIToken newImplementation = new TABIToken();

        // Store some initial state
        vm.startPrank(admin);
        token.mint(user1, 1000 * 10 ** 18);
        vm.stopPrank();
        uint256 initialBalance = token.balanceOf(user1);

        // Upgrade to new implementation
        vm.startPrank(admin);
        UUPSUpgradeable(address(token))
            .upgradeToAndCall(
                address(newImplementation),
                "" // No initialization data needed
            );
        vm.stopPrank();

        // Verify new implementation
        assertEq(address(newImplementation), _getImplementation());

        // Verify state is preserved
        assertEq(token.balanceOf(user1), initialBalance);

        // Verify new functionality works
        vm.startPrank(admin);
        token.mint(user2, 500 * 10 ** 18);
        assertEq(token.balanceOf(user2), 500 * 10 ** 18);
        vm.stopPrank();
    }

    /**
     * @dev Test suite for upgrade access control
     */
    function test_UpgradeAccessControl() public {
        TABIToken newImplementation = new TABIToken();

        // Test upgrade by non-admin
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")), user1, DEFAULT_ADMIN_ROLE
            )
        );
        UUPSUpgradeable(address(token)).upgradeToAndCall(address(newImplementation), "");
        vm.stopPrank();

        // Verify implementation didn't change
        assertEq(address(implementation), _getImplementation());
    }

    /**
     * @dev Test suite for role management
     */
    function test_RoleManagement() public {
        vm.startPrank(admin);

        // Test granting roles
        token.grantRole(MINTER_ROLE, minter);
        token.grantRole(PAUSER_ROLE, pauser);

        assertTrue(token.hasRole(MINTER_ROLE, minter));
        assertTrue(token.hasRole(PAUSER_ROLE, pauser));

        // Test revoking roles
        token.revokeRole(MINTER_ROLE, minter);
        token.revokeRole(PAUSER_ROLE, pauser);

        assertFalse(token.hasRole(MINTER_ROLE, minter));
        assertFalse(token.hasRole(PAUSER_ROLE, pauser));

        vm.stopPrank();
    }

    /**
     * @dev Test suite for minting functionality
     */
    function test_Minting() public {
        uint256 mintAmount = 1000 * 10 ** 18;

        // Test minting as admin
        vm.startPrank(admin);
        token.mint(user1, mintAmount);
        assertEq(token.balanceOf(user1), mintAmount);
        vm.stopPrank();

        // Test minting as authorized minter
        vm.startPrank(admin);
        token.grantRole(MINTER_ROLE, minter);
        vm.stopPrank();

        vm.startPrank(minter);
        token.mint(user2, mintAmount);
        assertEq(token.balanceOf(user2), mintAmount);
        vm.stopPrank();
    }

    /**
     * @dev Test suite for burning functionality
     */
    function test_Burning() public {
        uint256 mintAmount = 1000 * 10 ** 18;
        uint256 burnAmount = 400 * 10 ** 18;

        // Setup: mint tokens to user1
        vm.prank(admin);
        token.mint(user1, mintAmount);

        // Test burning own tokens
        vm.startPrank(user1);
        token.burn(burnAmount);
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        vm.stopPrank();

        // Test burnFrom with approval
        vm.prank(user1);
        token.approve(user2, burnAmount);

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);
        assertEq(token.balanceOf(user1), mintAmount - (2 * burnAmount));
    }

    /**
     * @dev Test suite for pause functionality
     */
    function test_PauseUnpause() public {
        uint256 amount = 100 * 10 ** 18;

        // Setup: mint tokens to user1
        vm.prank(admin);
        token.mint(user1, amount);

        // Test pause
        vm.prank(admin);
        token.pause();
        assertTrue(token.paused());

        // Test transfer while paused
        vm.startPrank(user1);
        vm.expectRevert();
        token.transfer(user2, amount);
        vm.stopPrank();

        // Test unpause
        vm.prank(admin);
        token.unpause();
        assertFalse(token.paused());

        // Test transfer after unpause
        vm.prank(user1);
        token.transfer(user2, amount);
        assertEq(token.balanceOf(user2), amount);
    }

    /**
     * @dev Additional tests to ensure paused state blocks mint/burn operations
     */
    function test_PauseBlocksMint() public {
        uint256 amount = 100 * 10 ** 18;

        // Pause by admin
        vm.prank(admin);
        token.pause();
        assertTrue(token.paused());

        // Mint should revert while paused (even by admin/minter)
        vm.startPrank(admin);
        vm.expectRevert();
        token.mint(user1, amount);
        vm.stopPrank();

        // Unpause restores functionality
        vm.prank(admin);
        token.unpause();
        assertFalse(token.paused());

        vm.prank(admin);
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);
    }

    function test_PauseBlocksBurn() public {
        uint256 amount = 100 * 10 ** 18;

        // Mint tokens to user1
        vm.prank(admin);
        token.mint(user1, amount);
        assertEq(token.balanceOf(user1), amount);

        // Pause by admin
        vm.prank(admin);
        token.pause();
        assertTrue(token.paused());

        // Burn should revert while paused
        vm.startPrank(user1);
        vm.expectRevert();
        token.burn(1);
        vm.stopPrank();

        // Unpause then burn succeeds
        vm.prank(admin);
        token.unpause();
        assertFalse(token.paused());

        vm.prank(user1);
        token.burn(1);
        assertEq(token.balanceOf(user1), amount - 1);
    }

    function test_PauseBlocksBurnFrom() public {
        uint256 amount = 100 * 10 ** 18;
        uint256 burnAmount = 10 * 10 ** 18;

        // Mint tokens to user1 and approve user2
        vm.prank(admin);
        token.mint(user1, amount);

        vm.prank(user1);
        token.approve(user2, burnAmount);

        // Pause by admin
        vm.prank(admin);
        token.pause();

        // burnFrom should revert while paused
        vm.startPrank(user2);
        vm.expectRevert();
        token.burnFrom(user1, burnAmount);
        vm.stopPrank();

        // Unpause then burnFrom succeeds
        vm.prank(admin);
        token.unpause();

        vm.prank(user2);
        token.burnFrom(user1, burnAmount);
        assertEq(token.balanceOf(user1), amount - burnAmount);
    }

    /**
     * @dev Test suite for failure cases
     */
    function test_Failures() public {
        uint256 amount = 100 * 10 ** 18;
        vm.prank(admin);
        token.mint(user1, amount);

        // Test unauthorized minting
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")), user1, MINTER_ROLE
            )
        );
        token.mint(user2, amount);
        vm.stopPrank();

        // Test unauthorized pausing
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)")), user1, PAUSER_ROLE
            )
        );
        token.pause();
        vm.stopPrank();

        // Test burning more than balance
        vm.prank(admin);
        token.mint(user1, amount);

        vm.startPrank(user1);
        vm.expectRevert();
        token.burn(amount * 3);
        vm.stopPrank();
    }

    /**
     * @dev Test suite for transfer functionality
     */
    function test_Transfers() public {
        uint256 amount = 100 * 10 ** 18;

        // Setup: mint tokens to user1
        vm.prank(admin);
        token.mint(user1, amount);

        // Test direct transfer
        vm.prank(user1);
        token.transfer(user2, amount / 2);
        assertEq(token.balanceOf(user2), amount / 2);
        assertEq(token.balanceOf(user1), amount / 2);

        // Test transferFrom
        vm.prank(user2);
        token.approve(user1, amount / 2);

        vm.prank(user1);
        token.transferFrom(user2, admin, amount / 4);
        assertEq(token.balanceOf(admin), amount / 4);
        assertEq(token.balanceOf(user2), amount / 4);
    }

    /**
     * @dev Helper function to get implementation address from proxy
     */
    function _getImplementation() internal view returns (address) {
        return address(
            uint160(
                uint256(vm.load(address(proxy), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc))
            )
        );
    }
}
