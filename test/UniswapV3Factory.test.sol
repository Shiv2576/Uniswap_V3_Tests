//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IUniswapV3Factory} from "src/uniswap-v3/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "src/uniswap-v3/IUniswapV3Pool.sol";
import {
    UNISWAP_V3_FACTORY,
    DAI,
    USDC,
    UNISWAP_V3_POOL_DAI_USDC_100
} from "src/Constants.sol";
import {ERC20} from "src/ERC20.sol";


contract UniswapV3FactoryTest is Test {

    IUniswapV3Factory public factory = IUniswapV3Factory(UNISWAP_V3_FACTORY);

    uint24 private constant Pool_Fee = 100;

    ERC20 private tokenA;
    ERC20 private tokenB;

    function setUp() public {
        tokenA = new ERC20("A", "A", 18);
        tokenB = new ERC20("B", "B", 18);
    }

    function testGetPool() public {
        address pool = factory.getPool( DAI, USDC , Pool_Fee);
        assertEq(pool, UNISWAP_V3_POOL_DAI_USDC_100 , "Pool should not exist yet");
    }

    function testCreatePool() public {
        address pool = factory.createPool(address(tokenA), address(tokenB), Pool_Fee);


        (address token0, address token1) = address(tokenA) <= address(tokenB)
            ? (address(tokenA), address(tokenB))
            : (address(tokenB), address(tokenA));

        assertEq(IUniswapV3Pool(pool).token0(), token0);
        assertEq(IUniswapV3Pool(pool).token1(), token1);
        assertEq(IUniswapV3Pool(pool).fee(), Pool_Fee);
    }


} 