--------------------------------------------------
--------------------------------------------------
contract ReentrancyGuard {
    uint256 private unlocked = 1;

    modifier nonReentrant() {
        require(unlocked == 1, "Reentrancy");
        unlocked = 0;
        _;
        unlocked = 1;
    }
}

LP TOKEN (MINIMAL ERC20)
--------------------------------------------------
--------------------------------------------------
contract SecureSwapDEX is ReentrancyGuard {
    struct Pool {
        address tokenA;
        address tokenB;
        LPToken lp;
        uint112 reserveA;
        uint112 reserveB;
        bool exists;
    }

    uint256 public poolCount;
    mapping(uint256 => Pool) public pools;

    event PoolCreated(uint256 indexed id, address tokenA, address tokenB);
    event LiquidityAdded(uint256 indexed id, address indexed provider, uint256 amountA, uint256 amountB, uint256 lpMinted);
    event LiquidityRemoved(uint256 indexed id, address indexed provider, uint256 amountA, uint256 amountB, uint256 lpBurned);
    event SwapExecuted(uint256 indexed id, address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    CREATE POOL
    --------------------------------------------------
    --------------------------------------------------
    function _updateReserves(uint256 id, uint256 newA, uint256 newB) internal {
        pools[id].reserveA = uint112(newA);
        pools[id].reserveB = uint112(newB);
    }

    ADD LIQUIDITY
    --------------------------------------------------
    --------------------------------------------------
    function removeLiquidity(uint256 id, uint256 lpAmount) external nonReentrant {
        Pool storage p = pools[id];
        require(p.exists, "Pool not found");

        uint256 supply = p.lp.totalSupply();

        uint256 amountA = (lpAmount * p.reserveA) / supply;
        uint256 amountB = (lpAmount * p.reserveB) / supply;

        p.lp.burn(msg.sender, lpAmount);

        IERC20(p.tokenA).transfer(msg.sender, amountA);
        IERC20(p.tokenB).transfer(msg.sender, amountB);

        _updateReserves(
            id,
            p.reserveA - amountA,
            p.reserveB - amountB
        );

        emit LiquidityRemoved(id, msg.sender, amountA, amountB, lpAmount);
    }

    SWAP FUNCTION
    x * y = k invariant swap with 0.30% fee
        uint256 amountInWithFee = (amountIn * 997) / 1000;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);

        require(amountOut > 0, "Invalid output amount");

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        --------------------------------------------------
    --------------------------------------------------
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a <= b ? a : b;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}
// 
Contract End
// 
