// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "BoringSolidity/interfaces/IERC20.sol";
import "BoringSolidity/BoringOwnable.sol";
import "OpenZeppelin/utils/Address.sol";
import "interfaces/IGmxGlpRewardHandler.sol";
import "interfaces/IMimCauldronDistributor.sol";
import "interfaces/IGmxRewardRouterV2.sol";
import "interfaces/IGmxRewardTracker.sol";

contract GlpWrapperHarvestor is BoringOwnable {
    using Address for address;
    event OperatorChanged(address indexed, bool);
    event DistributorChanged(IMimCauldronDistributor indexed, IMimCauldronDistributor indexed);
    error NotAllowedOperator();
    error ReturnRewardBalance(uint256 balance);

    IGmxGlpRewardHandler public immutable wrapper;
    IERC20 public immutable weth;

    IMimCauldronDistributor public distributor;
    IGmxRewardRouterV2 rewardRouterV2;

    mapping(address => bool) public operators;
    uint64 public lastExecution;

    modifier onlyOperators() {
        if (msg.sender != owner && !operators[msg.sender]) {
            revert NotAllowedOperator();
        }
        _;
    }

    constructor(
        IERC20 _weth,
        IGmxRewardRouterV2 _rewardRouterV2,
        IGmxGlpRewardHandler _wrapper,
        IMimCauldronDistributor _distributor
    ) {
        operators[msg.sender] = true;

        weth = _weth;
        rewardRouterV2 = _rewardRouterV2;
        wrapper = _wrapper;
        distributor = _distributor;
    }

    function claimable() external view returns (uint256) {
        return
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(wrapper)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(wrapper));
    }

    function totalWethBalanceAfterClaiming() external view returns (uint256) {
        return
            weth.balanceOf(address(wrapper)) +
            IGmxRewardTracker(rewardRouterV2.feeGmxTracker()).claimable(address(wrapper)) +
            IGmxRewardTracker(rewardRouterV2.feeGlpTracker()).claimable(address(wrapper));
    }

    function run(
        uint256 amountOutMin,
        IERC20 rewardToken,
        IERC20 outputToken,
        bytes calldata data
    ) external onlyOperators {
        wrapper.harvest();
        wrapper.swapRewards(amountOutMin, rewardToken, outputToken, address(distributor), data);
        distributor.distribute();
        lastExecution = uint64(block.timestamp);
    }

    function setDistributor(IMimCauldronDistributor _distributor) external onlyOwner {
        emit DistributorChanged(distributor, _distributor);
        distributor = _distributor;
    }

    function setOperator(address operator, bool status) external onlyOwner {
        operators[operator] = status;
        emit OperatorChanged(operator, status);
    }
}
