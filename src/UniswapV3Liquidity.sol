// SPDX-License-Identifier: MIT

import "./Interfaces/IWETH.sol";
import "./Interfaces/IERC20.sol";
import "./Interfaces/ISwapRouter.sol";
import "./Interfaces/IERC721Receiver.sol";
import "./Interfaces/INonfungiblePositionManager.sol";

pragma solidity ^0.8.13;

address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

contract UniswapV3Liquidity is IERC721Receiver {
    IERC20 private constant dai = IERC20(DAI);
    IWETH private constant weth = IWETH(WETH);

    int24 private constant MIN_TICK = -887272;
    int24 private constant MAX_TICK = -MIN_TICK;
    int24 private constant TICK_SPACING = 60;

    INonfungiblePositionManager public nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function mintNewPosition(
        uint256 amount0ToAdd,
        uint256 amount1ToAdd
    )
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        dai.transferFrom(msg.sender, address(this), amount0ToAdd);
        weth.transferFrom(msg.sender, address(this), amount1ToAdd);

        dai.approve(address(nonfungiblePositionManager), amount0ToAdd);
        weth.approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: DAI,
                token1: WETH,
                fee: 3000,
                // By using TickMath.MIN_TICK and TickMath.MAX_TICK,
                // we are providing liquidity across the whole range of the pool.
                // Not recommended in production.
                tickLower: (MIN_TICK / TICK_SPACING) * TICK_SPACING,
                tickUpper: (MAX_TICK / TICK_SPACING) * TICK_SPACING,
                amount0Desired: amount0ToAdd,
                amount1Desired: amount1ToAdd,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        (tokenId, liquidity, amount0, amount1) = nonfungiblePositionManager
            .mint(params);

        if (amount0 < amount0ToAdd) {
            dai.approve(address(nonfungiblePositionManager), 0);
            uint256 refund0 = amount0ToAdd - amount0;
            dai.transfer(msg.sender, refund0);
        }
        if (amount1 < amount1ToAdd) {
            weth.approve(address(nonfungiblePositionManager), 0);
            uint256 refund1 = amount1ToAdd - amount1;
            weth.transfer(msg.sender, refund1);
        }
    }

    function collectAllFees(
        uint256 tokenId
    ) external returns (uint256 amount0, uint256 amount1) {
        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params = INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0, amount1) = nonfungiblePositionManager.collect(params);
    }

    function increaseLiquidityCurrentRange(
        uint256 tokenId,
        uint256 amount0ToAdd,
        uint256 amount1ToAdd
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        dai.transferFrom(msg.sender, address(this), amount0ToAdd);
        weth.transferFrom(msg.sender, address(this), amount1ToAdd);

        dai.approve(address(nonfungiblePositionManager), amount0ToAdd);
        weth.approve(address(nonfungiblePositionManager), amount1ToAdd);

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: tokenId,
                    amount0Desired: amount0ToAdd,
                    amount1Desired: amount1ToAdd,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity, amount0, amount1) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    function decreaseLiquidityCurrentRange(
        uint256 tokenId,
        uint128 liquidity
    ) external returns (uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0, amount1) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );
    }
}
