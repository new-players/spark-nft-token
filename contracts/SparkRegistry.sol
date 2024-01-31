// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Interfaces/IERC6551Manager.sol";
import "./Interfaces/ISparkIdentity.sol";
import "./Helpers/Validator.sol";

/// @title SparkRegistry Contract
/// @author Venkatesh
/// @notice Manages the spark identity minting, payment and reward distribution for Spark Identity NFTs
/// @dev Extends ReentrancyGuard for non-reentrant methods and AccessControlEnumerable for role management
/// @custom:security-contact rvenki666@gmail.com
contract SparkRegistry is ReentrancyGuard, AccessControlEnumerable {
    using SafeERC20 for IERC20;

    /// @dev ERC721 interface id to check the ERC721 compatibility
    bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;

    /// @notice Address of the Spark Identity contract
    ISparkIdentity private immutable sparkIdentity;

    /// @notice Address of the ERC6551 Manager contract
    IERC6551Manager private erc6551Manager;

    /// @notice Enum for specifying the type of payment
    enum PaymentType {
        Native,
        Token,
        None
    }

    /// @notice Struct for holding payment payload information
    struct PaymentPayload {
        PaymentType paymentType;
        address paymentAddress;
    }

    /// @notice Struct for holding payment token information
    struct PaymentTokenInfo {
        bool isSupported;
        uint256 amount;
    }

    /// @notice Struct for holding payment configuration
    struct PaymentConfiguration {
        address beneficiaryAddress;
        bool isPaymentsEnabled;
        uint256 nativePaymentAmount;
        mapping(address => PaymentTokenInfo) paymentTokensInfo;
    }

    /// @notice Public payment configuration
    PaymentConfiguration public paymentConfiguration;

    /// @notice Struct for holding reward configuration
    struct RewardConfiguration {
        uint256 rewardsPerMint;
        uint256 maxRewardsPerUser;
        address rewardTokenAddress;
        bool isRewardsEnabled;
        mapping(address => bool) rewardableNfts;
    }

    /// @notice Public reward configuration
    RewardConfiguration public rewardConfiguration;

    /// @notice Mapping of user addresses to their earned rewards
    mapping(address => uint256) public userRewardsEarned;

    /// @notice Mapping of user addresses to their claimed rewards
    mapping(address => uint256) public userRewardsClaimed;

    /// @dev Custom errors for handling specific revert conditions
    error PaymentFailed();
    error RefundFailed();
    error PaymentNotRequired();
    error PaymentTokenNotSupported();
    error PaymentAmountCannotBeZero();
    error RewardAmountCannotBeZero();
    error MaxRewardsCannotBeZero();
    error NoRewardsToClaim();
    error RewardsPerMintShouldNotExceedsMaxRewards();
    error EmptyWhitelistNfts();
    error EmptyTokensInfo();
    error SizeMismatch();
    error InsufficientRewardsInTreasury();
    error InsufficientPayment();
    error InsufficientRewards();

    /// @notice Event emitted when a Spark Identity is minted
    event SparkIdentityMinted(address indexed toAddress, uint256 sparkId);

    /// @notice Event emitted when a Spark Identity is minted for an ERC6551 token
    event SparkIdentityMintedForERC6551(
        address indexed tokenboundAddress,
        address indexed nftAddress,
        uint256 indexed nftTokenId,
        uint256 sparkId
    );

    /// @notice Event emitted when rewards are claimed
    event RewardsClaimed(
        address indexed toAddress,
        address indexed rewardTokenAddress,
        uint256 rewards
    );

    /// @notice Event emitted when rewards are deposited
    event RewardsDeposited(
        address indexed fromAddress,
        address indexed rewardTokenAddress,
        uint256 rewards
    );

    /// @notice Event emitted when rewards are withdrawn
    event RewardsWithdrawn(
        address indexed toAddress,
        address indexed rewardTokenAddress,
        uint256 rewards
    );

    /// @notice Event emitted when a native payment is processed
    event NativePaymentProcessed(
        address indexed fromAddress,
        address indexed toAddress,
        uint256 amount
    );

    /// @notice Event emitted when a token payment is processed
    event TokenPaymentProcessed(
        address indexed fromAddress,
        address indexed toAddress,
        address indexed tokenAddress,
        uint256 amount
    );

    /// @notice Event emitted when a native payment refund is processed
    event NativePaymentRefundProcessed(
        address fromAddress,
        address toAddress,
        uint256 amount
    );

    /// @notice Event emitted when NFTs are added for rewards
    event NftsAddedForRewards(
        address byAddress,
        address[] nftAddresses,
        bool[] status
    );

    /// @notice Event emitted when payment tokens are added
    event PaymentTokensAdded(
        address byAddress,
        address[] tokenAddresses,
        uint256[] amounts,
        bool[] status
    );

    /**
     * @dev Initializes the contract by setting up various configurations and roles.
     * @param _sparkIdentityAddress Address of the Spark Identity contract.
     * @param _erc6551ManagerAddress Address of the ERC6551 Manager contract.
     * @param _rewardTokenAddress Address of the token used for rewards.
     * @param _beneficiaryAddress Address that will receive payments.
     * @param _admin Address that will be granted the default admin role.
     */
    constructor(
        address _sparkIdentityAddress,
        address _erc6551ManagerAddress,
        address _rewardTokenAddress,
        address _beneficiaryAddress,
        address _admin
    ) {
        Validator.checkForZeroAddress(_sparkIdentityAddress);
        Validator.checkForZeroAddress(_erc6551ManagerAddress);
        Validator.checkForZeroAddress(_rewardTokenAddress);
        Validator.checkForZeroAddress(_beneficiaryAddress);
        Validator.checkForZeroAddress(_admin);

        sparkIdentity = ISparkIdentity(_sparkIdentityAddress);
        erc6551Manager = IERC6551Manager(_erc6551ManagerAddress);

        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        paymentConfig.beneficiaryAddress = _beneficiaryAddress;

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        rewardConfig.rewardTokenAddress = _rewardTokenAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @dev Configures the ERC6551 Manager contract address.
     * @param _erc6551Manager New address of the ERC6551 Manager contract.
     */
    function configureERC6551Manager(
        address _erc6551Manager
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Validator.checkForZeroAddress(_erc6551Manager);

        erc6551Manager = IERC6551Manager(_erc6551Manager);
    }

    /**
     * @dev Retrieves the token-bound account for a given NFT.
     * @param _nftContractAddress Address of the NFT contract.
     * @param _tokenId Token ID of the NFT.
     * @return tokenboundAddress The address bound to the given NFT token.
     */
    function getNftTokenboundAccount(
        address _nftContractAddress,
        uint256 _tokenId
    ) external view returns (address tokenboundAddress) {
        Validator.checkForZeroAddress(_nftContractAddress);

        tokenboundAddress = erc6551Manager.getTokenBoundAccount(
            _nftContractAddress,
            _tokenId
        );
    }

    /**
     * @dev Configures payment settings for the contract.
     * @param _beneficiaryAddress Address that will receive payments.
     * @param _isPaymentEnabled Flag to enable or disable payments.
     * @param _nativePaymentAmount Amount required for native payments.
     */
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

    /**
     * @dev Adds supported payment tokens to the contract.
     * @param _tokens Array of token addresses to be added.
     * @param _amounts Array of amounts corresponding to each token.
     * @param _status Array of booleans indicating if the token is supported.
     */
    function addPaymentTokens(
        address[] calldata _tokens,
        uint256[] calldata _amounts,
        bool[] calldata _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 tokensLength = _tokens.length;

        if (tokensLength == 0) {
            revert EmptyTokensInfo();
        }

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

            if (isPaymentsEnabled && _amounts[i] == 0) {
                revert PaymentAmountCannotBeZero();
            }

            PaymentTokenInfo storage paymentTokenInfo = paymentConfig
                .paymentTokensInfo[_tokens[i]];

            paymentTokenInfo.amount = _amounts[i];
            paymentTokenInfo.isSupported = _status[i];

            unchecked {
                ++i;
            }
        } while (i < tokensLength);

        emit PaymentTokensAdded(msg.sender, _tokens, _amounts, _status);
    }

    /**
     * @dev Configures the rewards settings for minting and per user limits.
     * @param _rewardsPerMint The amount of rewards given per mint.
     * @param _maxRewardsPerUser The maximum rewards a single user can accumulate.
     * @param _isRewardsEnabled Flag to enable or disable rewards.
     */
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

    /**
     * @dev Deposits rewards into the contract.
     * @param _amount The amount of rewards to deposit.
     */
    function depositRewards(
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_amount == 0) {
            revert RewardAmountCannotBeZero();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        address rewardTokenAddress = rewardConfig.rewardTokenAddress;

        _transferTokensIn(rewardTokenAddress, msg.sender, _amount);

        emit RewardsDeposited(msg.sender, rewardTokenAddress, _amount);
    }

    /**
     * @dev Withdraws rewards from the contract.
     * @param _amount The amount of rewards to withdraw.
     */
    function withdrawRewards(
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_amount == 0) {
            revert RewardAmountCannotBeZero();
        }

        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        RewardConfiguration storage rewardConfig = rewardConfiguration;
        address rewardTokenAddress = rewardConfig.rewardTokenAddress;

        _transferTokensOut(
            rewardTokenAddress,
            paymentConfig.beneficiaryAddress,
            _amount
        );

        emit RewardsWithdrawn(msg.sender, rewardTokenAddress, _amount);
    }

    /**
     * @dev Whitelists NFTs for rewards eligibility.
     * @param _nftAddresses The addresses of the NFTs to whitelist.
     * @param _status The status to set for each NFT (true for whitelisted, false for not).
     */
    function whitelistNftsForRewards(
        address[] calldata _nftAddresses,
        bool[] calldata _status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 nftsLength = _nftAddresses.length;

        if (nftsLength == 0) {
            revert EmptyWhitelistNfts();
        }

        if (nftsLength != _status.length) {
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

        emit NftsAddedForRewards(msg.sender, _nftAddresses, _status);
    }

    /**
     * @dev Calculates the claimable rewards for a user.
     * @param _user The address of the user to calculate rewards for.
     * @return rewards The total claimable rewards for the user.
     */
    function claimableRewards(
        address _user
    ) public view returns (uint256 rewards) {
        Validator.checkForZeroAddress(_user);

        rewards = userRewardsEarned[_user] - userRewardsClaimed[_user];
    }

    /**
     * @dev Allows a user to claim their rewards.
     * @param _reward The amount of rewards the user wishes to claim.
     */
    function claimRewards(uint256 _reward) external nonReentrant {
        if (_reward == 0) {
            revert RewardAmountCannotBeZero();
        }

        uint256 claimableReward = claimableRewards(msg.sender);

        if (claimableReward == 0) {
            revert NoRewardsToClaim();
        }

        if (_reward > claimableReward) {
            revert InsufficientRewards();
        }

        RewardConfiguration storage rewardConfig = rewardConfiguration;
        address rewardTokenAddress = rewardConfig.rewardTokenAddress;

        if (_reward > IERC20(rewardTokenAddress).balanceOf(address(this))) {
            revert InsufficientRewardsInTreasury();
        }

        userRewardsClaimed[msg.sender] += _reward;

        IERC20(rewardTokenAddress).safeTransfer(msg.sender, _reward);

        emit RewardsClaimed(msg.sender, rewardTokenAddress, _reward);
    }

    /**
     * @dev Mints a new Spark Identity for a given address.
     * @param _to The address to mint the Spark Identity for.
     * @param paymentPayload The payment details for minting the Spark Identity.
     */
    function mintSparkIdentity(
        address _to,
        PaymentPayload calldata paymentPayload
    ) external nonReentrant {
        Validator.checkForZeroAddress(_to);

        _processPayment(paymentPayload);
        uint256 sparkId = sparkIdentity.safeMint(_to);
        _generateRewards(_to);

        emit SparkIdentityMinted(_to, sparkId);
    }

    /**
     * @dev Mints a new Spark Identity for a given NFT.
     * @param _nftContractAddress The address of the NFT contract.
     * @param _tokenId The ID of the NFT.
     * @param paymentPayload The payment details for minting the Spark Identity.
     */
    function mintSparkIdentityForNft(
        address _nftContractAddress,
        uint256 _tokenId,
        PaymentPayload calldata paymentPayload
    ) external nonReentrant {
        Validator.checkForZeroAddress(_nftContractAddress);

        _processPayment(paymentPayload);
        address tokenboundAddress = _createOrGetNftTokenboundAccount(
            _nftContractAddress,
            _tokenId
        );
        uint256 sparkId = sparkIdentity.safeMint(tokenboundAddress);
        _generateNftRewards(_nftContractAddress);

        emit SparkIdentityMintedForERC6551(
            tokenboundAddress,
            _nftContractAddress,
            _tokenId,
            sparkId
        );
    }

    /**
     * @dev Creates or retrieves a tokenbound account for a given NFT.
     * @param _nftAddress The address of the NFT.
     * @param _tokenId The ID of the NFT.
     * @return tokenboundAddress The address of the tokenbound account.
     */
    function _createOrGetNftTokenboundAccount(
        address _nftAddress,
        uint256 _tokenId
    ) internal returns (address tokenboundAddress) {
        tokenboundAddress = erc6551Manager.createTokenBoundAccount(
            _nftAddress,
            _tokenId
        );
    }

    /**
     * @dev Generates rewards for a given address.
     * @param _to The address to generate rewards for.
     */
    function _generateRewards(address _to) internal {}

    /**
     * @dev Generates rewards for a given NFT contract.
     * @param _nftContractAddress The address of the NFT contract.
     */
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

    /**
     * @dev Processes the payment for minting a Spark Identity.
     * @param paymentPayload The payment details for minting the Spark Identity.
     */
    function _processPayment(PaymentPayload calldata paymentPayload) internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        bool isPaymentsEnabled = paymentConfig.isPaymentsEnabled;

        if (
            !isPaymentsEnabled && paymentPayload.paymentType != PaymentType.None
        ) {
            revert PaymentNotRequired();
        }

        if (
            isPaymentsEnabled && paymentPayload.paymentType == PaymentType.None
        ) {
            revert PaymentFailed();
        }

        if (isPaymentsEnabled) {
            if (paymentPayload.paymentType == PaymentType.Native) {
                _processNativePayment();
            } else if (paymentPayload.paymentType == PaymentType.Token) {
                Validator.checkForZeroAddress(paymentPayload.paymentAddress);

                _processTokenPayment(paymentPayload.paymentAddress);
            }
        }
    }

    /**
     * @dev Processes a native payment for minting a Spark Identity.
     */
    function _processNativePayment() internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        uint256 amount = paymentConfig.nativePaymentAmount;

        if (amount > 0) {
            if (msg.value < amount) {
                revert InsufficientPayment();
            }

            uint256 excessAmount = msg.value - amount;
            address beneficiaryAddress = paymentConfig.beneficiaryAddress;

            (bool sent, ) = payable(beneficiaryAddress).call{value: amount}("");

            if (!sent) {
                revert PaymentFailed();
            }

            emit NativePaymentProcessed(msg.sender, beneficiaryAddress, amount);

            if (excessAmount > 0) {
                (bool refundSent, ) = payable(msg.sender).call{
                    value: excessAmount
                }("");

                if (!refundSent) {
                    revert RefundFailed();
                }

                emit NativePaymentRefundProcessed(address(this), msg.sender, excessAmount);
            }
        }
    }

    /**
     * @dev Processes a token payment for minting a Spark Identity.
     * @param _paymentAddress The address of the payment token.
     */
    function _processTokenPayment(address _paymentAddress) internal {
        PaymentConfiguration storage paymentConfig = paymentConfiguration;
        PaymentTokenInfo storage paymentTokenInfo = paymentConfig
            .paymentTokensInfo[_paymentAddress];

        if (!paymentTokenInfo.isSupported) {
            revert PaymentTokenNotSupported();
        }

        uint256 amount = paymentTokenInfo.amount;

        if (amount > 0) {
            address beneficiaryAddress = paymentConfig.beneficiaryAddress;

            _transferTokensIn(_paymentAddress, msg.sender, amount);
            _transferTokensOut(_paymentAddress, beneficiaryAddress, amount);

            emit TokenPaymentProcessed(
                msg.sender,
                beneficiaryAddress,
                _paymentAddress,
                amount
            );
        }
    }

    /**
     * @dev Transfers tokens into the contract.
     * @param _token The address of the token to transfer.
     * @param _from The address to transfer the tokens from.
     * @param _amount The amount of tokens to transfer.
     */
    function _transferTokensIn(
        address _token,
        address _from,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
    }

    /**
     * @dev Transfers tokens out of the contract.
     * @param _token The address of the token to transfer.
     * @param _to The address to transfer the tokens to.
     * @param _amount The amount of tokens to transfer.
     */
    function _transferTokensOut(
        address _token,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
