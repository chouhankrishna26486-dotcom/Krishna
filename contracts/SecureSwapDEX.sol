// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @title SecureSwap DEX
 * @notice A secure token-to-token AMM DEX with liquidity pools and LP tokens.
 * @dev This is a simplified but secure DEX model. 
 *      Add oracles, fee routing, permit(), TWAMM, etc. for advanced usage.
 */

interface IERC20 {
    function balanceOf(address user) external view returns (uint256);
    function transfer(address to, uint256 val) external returns (bool);
    function transferFrom(address from, address to, uint256 val) external returns (bool);
}

// --------------------------------------------------
// REENTRANCY PROTECTION
// --------------------------------------------------
contract ReentrancyGuard {
    uint256 private unlocked = 1;

    modifier nonReentrant() {
        require(unlocked == 1, "Reentrancy");
        unlocked = 0;
        _;
        unlocked = 1;
    }
}

// --------------------------------------------------
// LP TOKEN (MINIMAL ERC20)
// --------------------------------------------------
contract LPToken {
    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    address public dex;

    mapping(address => uint256) public balanceOf;

    modifier onlyDEX() {
        require(msg.sender == dex, "Not DEX");
        _;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        dex = msg.sender;
    }

    function mint(address to, uint256 amount) external onlyDEX {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint256 amount) external onlyDEX {
        require(balanceOf[from] >= amount, "Insufficient LP");
        balanceOf[from] -= amount;
        totalSupply -= amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Balance low");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// --------------------------------------------------
// SECURESWAP DEX
// --------------------------------------------------
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

    // --------------------------------------------------
    // CREATE POOL
    // --------------------------------------------------
    function createPool(address tokenA, address tokenB) external returns (uint256) {
        require(tokenA != tokenB, "Identical tokens");

        poolCount++;

        string memory lpName = "SecureSwap LP Token";
        string memory lpSymbol = "SS-LP";

        pools[poolCount] = Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            lp: new LPToken(lpName, lpSymbol),
            reserveA: 0,
            reserveB: 0,
            exists: true
        });

        emit PoolCreated(poolCount, tokenA, tokenB);
        return poolCount;
    }

    // --------------------------------------------------
    // INTERNAL RESERVE UPDATE
    // --------------------------------------------------
    function _updateReserves(uint256 id, uint256 newA, uint256 newB) internal {
        pools[id].reserveA = uint112(newA);
        pools[id].reserveB = uint112(newB);
    }

    // --------------------------------------------------
    // ADD LIQUIDITY
    // --------------------------------------------------
    function addLiquidity(
        uint256 id,
        uint256 amountA,
        uint256 amountB
    ) external nonReentrant {
        Pool storage p = pools[id];
        require(p.exists, "Pool not found");

        IERC20(p.tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(p.tokenB).transferFrom(msg.sender, address(this), amountB);

        uint256 lpMint;

        if (p.lp.totalSupply() == 0) {
            lpMint = sqrt(amountA * amountB);
        } else {
            lpMint = min(
                (amountA * p.lp.totalSupply()) / p.reserveA,
                (amountB * p.lp.totalSupply()) / p.reserveB
            );
        }

        p.lp.mint(msg.sender, lpMint);

        _updateReserves(
            id,
            p.reserveA + amountA,
            p.reserveB + amountB
        );

        emit LiquidityAdded(id, msg.sender, amountA, amountB, lpMint);
    }

    // --------------------------------------------------
    // REMOVE LIQUIDITY
    // --------------------------------------------------
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

    // --------------------------------------------------
    // SWAP FUNCTION
    // --------------------------------------------------
    function swap(
        uint256 id,
        address tokenIn,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        Pool storage p = pools[id];
        require(p.exists, "Pool not found");

        require(tokenIn == p.tokenA || tokenIn == p.tokenB, "Invalid token");

        bool isA = tokenIn == p.tokenA;

        address tokenOut = isA ? p.tokenB : p.tokenA;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint112 reserveIn = isA ? p.reserveA : p.reserveB;
        uint112 reserveOut = isA ? p.reserveB : p.reserveA;

        // x * y = k invariant swap with 0.30% fee
        uint256 amountInWithFee = (amountIn * 997) / 1000;
        amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);

        require(amountOut > 0, "Invalid output amount");

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        // update reserves
        if (isA) {
            _updateReserves(id, reserveIn + amountIn, reserveOut - amountOut);
        } else {
            _updateReserves(id, reserveIn + amountIn, reserveOut - amountOut);
        }

        emit SwapExecuted(id, msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // --------------------------------------------------
    // UTILS
    // --------------------------------------------------
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
