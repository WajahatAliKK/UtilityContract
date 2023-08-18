// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract TokenSwapAndClaim {
    address public owner;
    bytes32 private hashkey;
    IUniswapV2Router02 public uniswapRouter;

    // Tokens to be swapped
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public percentageTokenA;
    uint256 public percentageTokenB;

    constructor(
        address _uniswapRouter,
        address _tokenA,
        address _tokenB,
        uint256 _percentageTokenA,
        bytes32 _hashkey
    ) 
    {
        owner = msg.sender;
        hashkey = _hashkey;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        percentageTokenA = _percentageTokenA;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorized(bytes32 _providedHash) {
        require(_providedHash == hashkey, "Unauthorized");
        _;
    }

    function setAllocationPercentageAndTokens(uint256 _percentageTokenA, address _tokenA, address _tokenB) external onlyOwner {
        require(_percentageTokenA <= 100, "Total percentage exceeds 100");
        uint256 _percentageTokenB = 100 - _percentageTokenA;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        percentageTokenB = _percentageTokenB;
        percentageTokenA = _percentageTokenA;
    }

    function swapEthForTokens() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH balance");

        uint256 tokenAAmount = (ethBalance * percentageTokenA) / 100;
        uint256 tokenBAmount = (ethBalance * percentageTokenB) / 100;

        require(tokenAAmount > 0 && tokenBAmount > 0, "Invalid token amounts");

        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(tokenA);

        uniswapRouter.swapExactETHForTokens{value: tokenAAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );

        path[1] = address(tokenB);

        uniswapRouter.swapExactETHForTokens{value: tokenBAmount}(
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function claim(uint256 proportionalAmount, address tokenAddress, bytes32 _providedHash) external onlyAuthorized(_providedHash) {
        require(tokenAddress == address(tokenA) || tokenAddress == address(tokenB), "Invalid token address");

        uint256 tokenBalance = IERC20(tokenAddress).balanceOf(address(this));
        require(proportionalAmount <= tokenBalance, "Insufficient token balance");
        
        IERC20(tokenAddress).transfer(msg.sender, proportionalAmount);
    }

    function withdrawEth() external onlyOwner {
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH balance");

        payable(owner).transfer(ethBalance);
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
}
