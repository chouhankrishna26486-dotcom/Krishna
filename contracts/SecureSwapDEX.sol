// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title SecureSwap DEX
 * @notice Decentralized Token Swap with Liquidity Pools (AMM)
 */

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecureSwapDEX is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    mapping(address => uint256) public lpBalances;
    uint256 public totalLP;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event Swapped(address indexed user, uint256 amountIn, uint256 amountOut, string pair);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // ---------- Add Liquidity ----------
    function addLiquidity(uint256 amountA, uint256 amountB) external nonReentrant {
        require(amountA > 0 && amountB > 0, "Amounts must be > 0");

        tokenA.transferFrom(msg.sender, address(this), amountA);
        tokenB.transferFrom(msg.sender, address(this), amountB);

        uint256 lpMint;
        if (totalLP == 0) {
            lpMint = sqrt(amountA * amountB);
        } else {
            lpMint = min(
                (amountA * totalLP) / reserveA,
                (amountB * totalLP) / reserveB
            );
        }

        require(lpMint > 0, "LP amount too low");
        lpBalances[msg.sender] += lpMint;
        totalLP += lpMint;

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB, lpMint);
    }

    // ---------- Remove Liquidity ----------
    function removeLiquidity(uint256 lpAmount) external nonReentrant {
        require(lpBalances[msg.sender] >= lpAmount, "Insufficient LP");

        uint256 share = (lpAmount * 1e18) / totalLP;

        uint256 amountA = (reserveA * share) / 1e18;
        uint256 amountB = (reserveB * share) / 1e18;

        lpBalances[msg.sender] -= lpAmount;
        totalLP -= lpAmount;

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, lpAmount);
    }

    // ---------- Swap A → B ----------
    function swapAforB(uint256 amountAIn) external nonReentrant {
        require(amountAIn > 0, "Amount must be > 0");

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        uint256 amountBOut = getAmountOut(amountAIn, reserveA, reserveB);

        reserveA += amountAIn;
        reserveB -= amountBOut;

        tokenB.transfer(msg.sender, amountBOut);
        emit Swapped(msg.sender, amountAIn, amountBOut, "A->B");
    }

    // ---------- Swap B → A ----------
    function swapBforA(uint256 amountBIn) external nonReentrant {
        require(amountBIn > 0, "Amount must be > 0");

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        uint256 amountAOut = getAmountOut(amountBIn, reserveB, reserveA);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        tokenA.transfer(msg.sender, amountAOut);
        emit Swapped(msg.sender, amountBIn, amountAOut, "B->A");
    }

    // ---------- AMM Pricing (x*y=k) ----------
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        return numerator / denominator;
    }

    // ---------- Helpers ----------
    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x > 3) {
            y = x;
            uint256 z = (x / 2) + 1;
            while (z < y) {
                y = z;
                z = ((x / z) + z) / 2;
            }
        } else if (x != 0) {
            y = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    // ---------- User View ----------
    function getUserLP(address user) external view returns (uint256) {
        return lpBalances[user];
    }

    function getPriceAtoB(uint256 amountAIn) external view returns (uint256) {
        return getAmountOut(amountAIn, reserveA, reserveB);
    }

    function getPriceBtoA(uint256 amountBIn) external view returns (uint256) {
        return getAmountOut(amountBIn, reserveB, reserveA);
    }
}
