// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SecureSwap DEX
 * @dev Decentralized Exchange with automated market maker functionality
 */
contract SecureSwapDEX {
    
    // State variables
    address public owner;
    uint256 public feePercentage; // Fee in basis points (e.g., 30 = 0.3%)
    uint256 public totalLiquidity;
    
    mapping(address => uint256) public liquidityProviders;
    mapping(address => mapping(address => uint256)) public userBalances;
    mapping(address => bool) public supportedTokens;
    
    // Events
    event LiquidityAdded(address indexed provider, uint256 amount, uint256 timestamp);
    event LiquidityRemoved(address indexed provider, uint256 amount, uint256 timestamp);
    event TokenSwapped(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event TokenAdded(address indexed token, uint256 timestamp);
    event TokenRemoved(address indexed token, uint256 timestamp);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validToken(address token) {
        require(supportedTokens[token], "Token not supported");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        feePercentage = 30; // 0.3% default fee
    }
    
    /**
     * @dev Function 1: Add liquidity to the DEX
     * @param amount Amount of liquidity to add
     */
    function addLiquidity(uint256 amount) external payable {
        require(amount > 0 || msg.value > 0, "Amount must be greater than zero");
        
        uint256 liquidityAmount = amount > 0 ? amount : msg.value;
        liquidityProviders[msg.sender] += liquidityAmount;
        totalLiquidity += liquidityAmount;
        
        emit LiquidityAdded(msg.sender, liquidityAmount, block.timestamp);
    }
    
    /**
     * @dev Function 2: Remove liquidity from the DEX
     * @param amount Amount of liquidity to remove
     */
    function removeLiquidity(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(liquidityProviders[msg.sender] >= amount, "Insufficient liquidity");
        
        liquidityProviders[msg.sender] -= amount;
        totalLiquidity -= amount;
        
        payable(msg.sender).transfer(amount);
        
        emit LiquidityRemoved(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Function 3: Swap tokens with automated pricing
     * @param tokenIn Address of input token
     * @param tokenOut Address of output token
     * @param amountIn Amount of input tokens
     */
    function swapTokens(address tokenIn, address tokenOut, uint256 amountIn) 
        external 
        validToken(tokenIn) 
        validToken(tokenOut) 
    {
        require(amountIn > 0, "Amount must be greater than zero");
        require(userBalances[msg.sender][tokenIn] >= amountIn, "Insufficient balance");
        
        uint256 fee = (amountIn * feePercentage) / 10000;
        uint256 amountAfterFee = amountIn - fee;
        
        // Simplified AMM formula (constant product)
        uint256 amountOut = calculateSwapAmount(amountAfterFee);
        
        userBalances[msg.sender][tokenIn] -= amountIn;
        userBalances[msg.sender][tokenOut] += amountOut;
        
        emit TokenSwapped(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    /**
     * @dev Function 4: Deposit tokens to the DEX
     * @param token Address of the token
     * @param amount Amount to deposit
     */
    function depositToken(address token, uint256 amount) external validToken(token) {
        require(amount > 0, "Amount must be greater than zero");
        
        userBalances[msg.sender][token] += amount;
    }
    
    /**
     * @dev Function 5: Withdraw tokens from the DEX
     * @param token Address of the token
     * @param amount Amount to withdraw
     */
    function withdrawToken(address token, uint256 amount) external validToken(token) {
        require(amount > 0, "Amount must be greater than zero");
        require(userBalances[msg.sender][token] >= amount, "Insufficient balance");
        
        userBalances[msg.sender][token] -= amount;
    }
    
    /**
     * @dev Function 6: Add supported token
     * @param token Address of the token to add
     */
    function addSupportedToken(address token) external onlyOwner {
        require(!supportedTokens[token], "Token already supported");
        
        supportedTokens[token] = true;
        
        emit TokenAdded(token, block.timestamp);
    }
    
    /**
     * @dev Function 7: Remove supported token
     * @param token Address of the token to remove
     */
    function removeSupportedToken(address token) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        
        supportedTokens[token] = false;
        
        emit TokenRemoved(token, block.timestamp);
    }
    
    /**
     * @dev Function 8: Update trading fee
     * @param newFee New fee percentage in basis points
     */
    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee cannot exceed 10%");
        
        uint256 oldFee = feePercentage;
        feePercentage = newFee;
        
        emit FeeUpdated(oldFee, newFee);
    }
    
    /**
     * @dev Function 9: Get user balance for a specific token
     * @param user Address of the user
     * @param token Address of the token
     * @return Balance of the user
     */
    function getUserBalance(address user, address token) external view returns (uint256) {
        return userBalances[user][token];
    }
    
    /**
     * @dev Function 10: Transfer ownership
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        
        address previousOwner = owner;
        owner = newOwner;
        
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Internal function to calculate swap amount (simplified AMM)
     * @param amountIn Input amount after fees
     * @return Output amount
     */
    function calculateSwapAmount(uint256 amountIn) internal pure returns (uint256) {
        // Simplified calculation - in production, use proper AMM formula
        return (amountIn * 98) / 100; // 2% slippage simulation
    }
    
    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        totalLiquidity += msg.value;
        liquidityProviders[msg.sender] += msg.value;
    }
}