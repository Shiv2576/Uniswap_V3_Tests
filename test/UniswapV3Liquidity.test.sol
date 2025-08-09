//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;
import {Test, console2} from "forge-std/Test.sol";
import {INonfungiblePositionManager} from "src/uniswap-v3/INonfungiblePositionManager.sol";
import {
    UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER,
    DAI,
    WETH
} from "src/Constants.sol";
import {IWETH} from "src/IWETH.sol";

import {IERC20} from "src/IERC20.sol";

struct Position {
    uint96 nonce;
    address operator;
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
    uint256 feeGrowthInside0LastX128;
    uint256 feeGrowthInside1LastX128;
    uint128 tokensOwed0;
    uint128 tokensOwed1;
}

contract UniswapLiquidityTest is Test {
    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);

    INonfungiblePositionManager private manager = INonfungiblePositionManager(
        UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER
    );

    int24 private constant TICK_LOWER = -887272;
    int24 private constant TICK_UPPER = 887272;
    int24 private constant TICK_SPACING = 60;


    function setUp() public {
        deal(DAI , address(this), 1e6 * 1e18);
        deal(WETH, address(this), 1e6 * 1e18);

        dai.approve(UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER, type(uint256).max);
        weth.approve(UNISWAP_V3_NONFUNGIBLE_POSITION_MANAGER, type(uint256).max);
    }

    function mint() public returns(uint256 tokenId) {
        (tokenId,,,) = manager.mint(
            INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH,
                fee: 3000,
                tickLower: TICK_LOWER / TICK_SPACING * TICK_SPACING,
                tickUpper: TICK_UPPER / TICK_SPACING * TICK_SPACING,
                amount0Desired: 1000 * 1e18, 
                amount1Desired: 1e18, 
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );
    }

    function get_Position(uint256 tokenId) private view returns(Position memory) {
        (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = manager.positions(tokenId);

        Position memory position = Position({
            nonce: nonce,
            operator: operator,
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidity: liquidity,
            feeGrowthInside0LastX128: feeGrowthInside0LastX128,
            feeGrowthInside1LastX128: feeGrowthInside1LastX128,
            tokensOwed0: tokensOwed0,
            tokensOwed1: tokensOwed1
        });

        return position;

    }

    function test_mint() public {
        (uint256 tokenId, uint128 liquidity , uint256 amount0 , uint256 amount1) = manager.mint(
            INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH,
                fee: 3000,
                tickLower: TICK_LOWER / TICK_SPACING * TICK_SPACING,
                tickUpper: TICK_UPPER / TICK_SPACING * TICK_SPACING,
                amount0Desired: 1000 * 1e18, 
                amount1Desired: 1e18, 
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        console2.log("Amount 0 added %e", amount0);
        console2.log("Amount 1 added %e", amount1);

        assertEq(manager.ownerOf(tokenId), address(this));

        Position memory position = get_Position(tokenId);
        assertEq(position.token0, DAI);
        assertEq(position.token1, WETH);
        assertGt(position.liquidity, 0);
    }

    function test_increaseLiquidity() public {
        uint256 tokenId = mint();

        Position memory p0 = get_Position(tokenId);

        (uint128 liquidityDelta , uint256 amount0 , uint256 amount1) = manager.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: 1000 * 1e18,
                amount1Desired: 1e18,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        Position memory p1 = get_Position(tokenId);



        assertGt(p1.liquidity, p0.liquidity , "Liquidity should increase");
        assertGt(liquidityDelta, 0 );

    }

    function test_decreaseLiquidity() public {
        uint256 tokenId = mint();

        Position memory p0 = get_Position(tokenId);

        (uint256 amount0 , uint256 amount1) = manager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: p0.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        Position memory p1 = get_Position(tokenId);

        assertEq(p1.liquidity, 0, "Liquidity should be 0 after decrease");
        assertGt(p1.tokensOwed0, 0, "Tokens owed 0 should be greater than 0");
        assertGt(p1.tokensOwed1, 0, "Tokens owed 1 should be greater than 0");
    }

    function test_collect() public {
        uint256 tokenId = mint();
        Position memory p0 = get_Position(tokenId);

        manager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: p0.liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            })
        );

        (uint256 amount0, uint256 amount1) = manager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        Position memory p1 = get_Position(tokenId);

        assertEq(p1.liquidity ,0 ,  "Liquidity should be 0 after collect");
        assertEq(p1.tokensOwed0, 0, "Tokens owed 0 should be 0 after collect");
        assertEq(p1.tokensOwed1, 0, "Tokens owed 1 should be 0 after collect");
    }



}
