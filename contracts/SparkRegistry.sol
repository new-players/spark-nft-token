// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Interfaces/ISparkIdentity.sol";
import "./Helpers/Validator.sol";

contract SparkRegistry is AccessControlEnumerable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error PaymentFailed();
    error RefundFailed();
    error PaymentTokenNotSupported();
    error PaymentAmountCannotBeZero();
    error RewardAmountCannotBeZero();
    error MaxRewardsCannotBeZero();
    error NoRewardsToClaim();
    error RewardsPerMintShouldNotExceedsMaxRewards();
    error EmptyWhitelistNfts();
    error SizeMismatch();
    error InsufficientRewardsInTreasury();
    error InsufficientPayment();

    // ERC721 interface id to check the ERC721 compatibility
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    ISparkIdentity private immutable sparkIdentity;

    enum PaymentType {
        Native,
        Token
    }

    struct PaymentTokenInfo {
        uint256 amount;
        bool isSupported;
    }

    struct PaymentConfiguration {
        address beneficiaryAddress;
        bool isPaymentsEnabled;
        uint256 nativePaymentAmount;
        mapping(address => PaymentTokenInfo) paymentTokensInfo;
    }

    struct RewardConfiguration {
        uint256 rewardsPerMint;
        uint256 maxRewardsPerUser;
        bool isRewardsEnabled;
        address rewardTokenAddress;
        mapping(address => bool) rewardableNfts;
    }

    PaymentConfiguration public paymentConfiguration;

    RewardConfiguration public rewardConfiguration;
    mapping(address => uint256) public userRewardsEarned;
    mapping(address => uint256) public userRewardsClaimed;

    constructor(
        address _sparkIdentityAddress,
        address _beneficiaryAddress,
        address _rewardTokenAddress,
        address _admin
    ) {
        Validator.checkForZeroAddress(_sparkIdentityAddress);
        Validator.checkForZeroAddress(_admin);
        Validator.checkForZeroAddress(_beneficiaryAddress);
        Validator.checkForZeroAddress(_rewardTokenAddress);

        sparkIdentity = ISparkIdentity(_sparkIdentityAddress);

        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        paymentConfig.beneficiaryAddress = _beneficiaryAddress;

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        rewardConfig.rewardTokenAddress = _rewardTokenAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function configurePayment(
        address _beneficiaryAddress,
        bool _isPaymentEnabled,
        uint256 _nativePaymentAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Validator.checkForZeroAddress(_beneficiaryAddress);

        if (_isPaymentEnabled && _nativePaymentAmount == 0) {
            revert PaymentAmountCannotBeZero();
        }

        PaymentConfiguration storage paymentConfig = paymentConfiguration;

        paymentConfig.beneficiaryAddress = _beneficiaryAddress;
        paymentConfig.isPaymentsEnabled = _isPaymentEnabled;
        paymentConfig.nativePaymentAmount = _nativePaymentAmount;
    }

    function addPaymentTokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        bool[] calldata _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tokensLength = _tokens.length;

        if (tokensLength != _amounts.length) {
            revert SizeMismatch();
        }

        if (tokensLength != _status.length) {
            revert SizeMismatch();
        }

        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        bool isPaymentsEnabled = paymentConfig.isPaymentsEnabled;

        uint256 i = 0;
        do {
            Validator.checkForZeroAddress(_tokens[i]);

            PaymentTokenInfo storage paymentTokenInfo = paymentConfig
                .paymentTokensInfo[_tokens[i]];

            if (isPaymentsEnabled && _amounts[i] == 0) {
                revert PaymentAmountCannotBeZero();
            }

            paymentTokenInfo.amount = _amounts[i];
            paymentTokenInfo.isSupported = _status[i];

            unchecked {
                ++i;
            }
        } while (i < tokensLength);
    }

    function configureRewards(
        uint256 _rewardsPerMint,
        uint256 _maxRewardsPerUser,
        bool _isRewardsEnabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_isRewardsEnabled && _rewardsPerMint == 0) {
            revert RewardAmountCannotBeZero();
        }

        if (_isRewardsEnabled && _maxRewardsPerUser == 0) {
            revert MaxRewardsCannotBeZero();
        }

        if (_rewardsPerMint > _maxRewardsPerUser) {
            revert RewardsPerMintShouldNotExceedsMaxRewards();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        rewardConfig.rewardsPerMint = _rewardsPerMint;
        rewardConfig.maxRewardsPerUser = _maxRewardsPerUser;
        rewardConfig.isRewardsEnabled = _isRewardsEnabled;
    }

    function depositRewards(
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_amount == 0) {
            revert RewardAmountCannotBeZero();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;

        _transferTokensIn(rewardConfig.rewardTokenAddress, msg.sender, _amount);
    }

    function withdrawRewards(
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_amount == 0) {
            revert RewardAmountCannotBeZero();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        PaymentConfiguration storage paymentConfig = paymentConfiguration;

        _transferTokensOut(
            rewardConfig.rewardTokenAddress,
            paymentConfig.beneficiaryAddress,
            _amount
        );
    }

    function whitelistNftsForRewards(
        address[] calldata _nftAddresses,
        bool[] calldata _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 nftsLength = _nftAddresses.length;

        if (nftsLength == 0) {
            revert EmptyWhitelistNfts();
        }

        if (_status.length != nftsLength) {
            revert SizeMismatch();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;

        uint256 i = 0;
        do {
            Validator.checkForZeroAddress(_nftAddresses[i]);
            Validator.checkSupportsInterface(
                _nftAddresses[i],
                INTERFACE_ID_ERC721
            );

            rewardConfig.rewardableNfts[_nftAddresses[i]] = _status[i];

            unchecked {
                ++i;
            }
        } while (i < nftsLength);
    }

    function mintSparkIdentityWithNative(address _to) external nonReentrant {
        _processPayment(PaymentType.Native, address(0));
        sparkIdentity.safeMint(_to);
        _generateRewards();
    }

    function mintSparkIdentityWithToken(
        address _to,
        address _paymentAddress
    ) external nonReentrant {
        _processPayment(PaymentType.Token, _paymentAddress);
        sparkIdentity.safeMint(_to);
        _generateRewards();
    }

    function mintSparkIdentityForNftWithNative(
        address _nftContractAddress,
        uint256 _tokenId
    ) external nonReentrant {
        _processPayment(PaymentType.Native, address(0));
        sparkIdentity.safeMintERC6551(_nftContractAddress, _tokenId);
        _generateNftRewards(_nftContractAddress);
    }

    function mintSparkIdentityForNftWithToken(
        address _nftContractAddress,
        uint256 _tokenId,
        address _paymentAddress
    ) external nonReentrant {
        _processPayment(PaymentType.Token, _paymentAddress);
        sparkIdentity.safeMintERC6551(_nftContractAddress, _tokenId);
        _generateNftRewards(_nftContractAddress);
    }

    function claimableRewards(
        address _user
    ) public view returns (uint256 rewards) {
        Validator.checkForZeroAddress(_user);

        rewards = userRewardsEarned[_user] - userRewardsClaimed[_user];
    }

    function claimRewards() external nonReentrant {
        uint256 reward = claimableRewards(msg.sender);

        if (reward == 0) {
            revert NoRewardsToClaim();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        IERC20 rewardToken = IERC20(rewardConfig.rewardTokenAddress);

        if (reward > rewardToken.balanceOf(address(this))) {
            revert InsufficientRewardsInTreasury();
        }

        userRewardsClaimed[msg.sender] += reward;

        rewardToken.safeTransfer(msg.sender, reward);
    }

    function _generateRewards() internal {}

    function _generateNftRewards(address _nftContractAddress) internal {
        RewardConfiguration storage rewardConfig = rewardConfiguration;
        uint256 reward = rewardConfig.rewardsPerMint;
        uint256 earnedRewards = userRewardsEarned[msg.sender];

        if (
            rewardConfig.isRewardsEnabled &&
            rewardConfig.rewardableNfts[_nftContractAddress] &&
            (earnedRewards + reward) <= rewardConfig.maxRewardsPerUser
        ) {
            userRewardsEarned[msg.sender] = earnedRewards + reward;
        }
    }

    function _processPayment(
        PaymentType _type,
        address _paymentAddress
    ) internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;

        if (paymentConfig.isPaymentsEnabled) {
            if (_type == PaymentType.Native) {
                _processNativePayment();
            } else {
                Validator.checkForZeroAddress(_paymentAddress);
                _processTokenPayment(_paymentAddress);
            }
        }
    }

    function _processNativePayment() internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        uint256 amount = paymentConfig.nativePaymentAmount;

        if (amount > 0) {
            if (msg.value < amount) {
                revert InsufficientPayment();
            }

            uint256 excessAmount = msg.value - amount;

            (bool sent, ) = payable(paymentConfig.beneficiaryAddress).call{
                value: amount
            }("");

            if (!sent) {
                revert PaymentFailed();
            }

            if (excessAmount > 0) {
                (bool refundSent, ) = payable(msg.sender).call{
                    value: excessAmount
                }("");

                if (!refundSent) {
                    revert RefundFailed();
                }
            }
        }
    }

    function _processTokenPayment(address _paymentAddress) internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        PaymentTokenInfo storage paymentTokenInfo = paymentConfig
            .paymentTokensInfo[_paymentAddress];

        if (!paymentTokenInfo.isSupported) {
            revert PaymentTokenNotSupported();
        }

        uint256 amount = paymentTokenInfo.amount;

        if (amount > 0) {
            _transferTokensIn(_paymentAddress, msg.sender, amount);
            _transferTokensOut(
                _paymentAddress,
                paymentConfig.beneficiaryAddress,
                amount
            );
        }
    }

    function _transferTokensIn(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
    }

    function _transferTokensOut(
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
