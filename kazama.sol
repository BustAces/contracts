//    ___  __    ________  ________  ________  _____ ______   ________          ________  _______   ________   ________  ___  ___  ___     
//   |\  \|\  \ |\   __  \|\_____  \|\   __  \|\   _ \  _   \|\   __  \        |\   ____\|\  ___ \ |\   ___  \|\   ____\|\  \|\  \|\  \    
//   \ \  \/  /|\ \  \|\  \\|___/  /\ \  \|\  \ \  \\\__\ \  \ \  \|\  \       \ \  \___|\ \   __/|\ \  \\ \  \ \  \___|\ \  \\\  \ \  \   
//    \ \   ___  \ \   __  \   /  / /\ \   __  \ \  \\|__| \  \ \   __  \       \ \_____  \ \  \_|/_\ \  \\ \  \ \_____  \ \   __  \ \  \  
//     \ \  \\ \  \ \  \ \  \ /  /_/__\ \  \ \  \ \  \    \ \  \ \  \ \  \       \|____|\  \ \  \_|\ \ \  \\ \  \|____|\  \ \  \ \  \ \  \ 
//      \ \__\\ \__\ \__\ \__\\________\ \__\ \__\ \__\    \ \__\ \__\ \__\        ____\_\  \ \_______\ \__\\ \__\____\_\  \ \__\ \__\ \__\
//       \|__| \|__|\|__|\|__|\|_______|\|__|\|__|\|__|     \|__|\|__|\|__|       |\_________\|_______|\|__| \|__|\_________\|__|\|__|\|__|
//                                                                                \|_________|               _________|                                                                                                                                                 
//        - あなたは調整し、事実を分析し、結論を導き出します。
//        - Cooper
//
//        - SPDX-License-Identifier: MIT

pragma solidity ^0.8.21;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract KazamaSenshi is ERC20, ERC20Burnable, AccessControl {

    // General
    KazamaRouter Router;
    DividendDistributor Distributor;
    KazamaBurnGame BurnGame;
    ERC20 public rewardToken;

    uint256 private _maxSupply;
    uint256 private _totalSupply;
    uint256 private MAX_INT = 2**256 - 1;

    uint256 private autoBuyBackCap;
    uint256 private autoBuyBackAccumulator;
    uint256 private autoBuyBackAmount;
    uint256 private autoBuyBackBlockPeriod;
    uint256 private autoBuyBackBlockLast;
    uint256 private buyBackMultiplierLength;
    uint256 private buyBackMultiplierNumerator;
    uint256 private buyBackMultiplierDenominator;
    uint256 private buyBackMultiplierTriggeredAt;
    uint256 private liquidityDenominator;
    uint256 private targetLiquidity;

    uint256 public autoBurnPercentage;
    uint256 public allTimeBurned;
    uint256 public topBurnAmount;
    uint256 public feeDenominator;
    uint256 public swapThreshold;
    uint256 public totalFee;
    uint256 public liqGeneratorFee;
    uint256 public buyBackBurnFee;
    uint256 public treasuryFee;
    uint256 public rewardsFee;
    uint256 public distributorGas;

    address public burnAddress;
    address public burnGameAddress;
    address public deadAddress;
    address public distributorAddress;
    address public kazamaPair;
    address public topBurner;
    address public zaibatsuHoldings;
    address public WETH = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    bool public autoSwapActive;
    bool public autoSwapEnabled;
    bool public autoBuyBackActive;
    bool public feesEnabled;
    bool public maxSupplyLocked;
    
    // Senshi NFT data
    SenshiNFT Senshi;

    bool public senshiSaleActive;
    address public senshiNFT;
    uint256 public senshiPrice;

    // Mappings
    mapping (address => mapping (address => uint256)) _allowances;
    mapping (address => uint256) _balances;
    mapping (address => bool) isFeeExempt;
    mapping (address => bool) buyBacker;
    mapping (address => bool) burnExempt;
    mapping (address => bool) isDividendExempt;
    mapping (address => bool) excludedAddresses;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Profile data
    mapping (address => uint256) totalBurned;
    mapping (address => uint256) sendedTips;
    mapping (address => uint256) sendedAmount;
    mapping (address => uint256) receivedTips;
    mapping (address => uint256) receivedAmount;
    mapping (address => uint256) senshiNftPurchased;

    // Platform chat rain struct, mapping and settings
    uint256 maxSpots;

    struct RainStruct {
        bool rainActive;
        uint256 rainAmount;
        uint256 rainSpots;
        uint256 rainAmountPerSpot;
        uint256 rainParticipants;
        address rainerAddress;
        address rainToken;
    }

    // Output RainStruct to public
    RainStruct public rainData;

    // Events
    event autoLiquify (uint256 amountNative, uint256 amountBOG);
    event buyBackMultiplierActive (uint256 duration);
    event distributionData (uint256 minPeriod, uint256 minDistribution);

    // Deployment constructor
    constructor (
        address _deadAddress,
        address _kazamaRouter,
        address _rewardToken,
        uint256 _autoBurnPercentage,
        uint256 _buyBackBurnFee,
        uint256 _liqGeneratorFee,
        uint256 _rewardsFee,
        uint256 _startSupply,
        uint256 _treasuryFee

        // Set token data
        ) ERC20 ("Bababooey Token", "BOEY") {

        // Requirements checks
        require (_autoBurnPercentage <= 7 && _autoBurnPercentage > 0, "ERROR [_autoBurnPercentage]: Minimum of 1 and maximum of 7");
        require (_buyBackBurnFee <= 3 && _buyBackBurnFee > 0, "ERROR [_buyBackBurnFee]: Minimum of 1 and maximum of 3");
        require (_liqGeneratorFee <= 3 && _liqGeneratorFee > 0, "ERROR [_liqGeneratorFee]: Minimum of 1 and maximum of 3");
        require (_rewardsFee <= 5 && _rewardsFee > 0, "ERROR [_rewardsFee]: Minimum of 1 and maximum of 5");
        require (_treasuryFee <= 2 && _treasuryFee > 0, "ERROR [_treasuryFee]: Minimum of 1 and maximum of 2");

        // Initiate constructor router/pair
        Router = KazamaRouter (_kazamaRouter);
        kazamaPair = KazamaFactory (Router.factory()).createPair(WETH, address(this));
        WETH = Router.WETH();
        rewardToken = ERC20(_rewardToken);
        Distributor = new DividendDistributor(_kazamaRouter);
        BurnGame = new KazamaBurnGame();
        Senshi = new SenshiNFT(msg.sender, address(this));
        senshiNFT = address(Senshi);
        burnGameAddress = address(BurnGame);
        distributorAddress = address(Distributor);

        // Initiate constructor misc data
        _allowances [address(this)] [address (Router)] = MAX_INT;
        _maxSupply = MAX_INT;
        _mint(msg.sender, _startSupply * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _totalSupply = _startSupply;
        senshiPrice = 95 * (10 ** 18);
        distributorGas = 500000;
        feeDenominator = 100;
        autoSwapEnabled = true;

        // Initiate constructor manually provided data
        autoBurnPercentage = _autoBurnPercentage;
        buyBackBurnFee = _buyBackBurnFee;
        deadAddress = _deadAddress;
        liqGeneratorFee = _liqGeneratorFee;
        rewardsFee = _rewardsFee;
        treasuryFee = _treasuryFee;

        // Initiate total fee based on constructor provided data
        totalFee = 
        _autoBurnPercentage + 
        _buyBackBurnFee + 
        _liqGeneratorFee + 
        _rewardsFee + 
        _treasuryFee;
    }

    // Modifier burn excluded receiver addresses (differs from burnExempt)
    modifier notExcluded (address _address) {
        require(!excludedAddresses[_address]);
        _;
    }

    // Modifier to check if contract is swapping
    modifier autoSwap() {
        autoSwapActive = true; 
        _; 
        autoSwapActive = false;
    }

    // Function to create a rain on KazamaSwap platform chat
    function createRain (address _rainToken, uint256 _rainAmount, uint256 _rainParticipants) external {
        require (!rainData.rainActive, "ERROR: Another rain active, wait until finished");
        require (_rainParticipants <= maxSpots, "ERROR: Rain spots exceeds maxSpots");

        uint256 burnAmount = 0;
        uint256 reflectionCut = 0;
        uint256 totalCut = 0;

        // Check if rain token is KAZAMA due reflection + auto burn
        if (_rainToken == address(this)) {

            if (feesEnabled) {
                if (!isFeeExempt[msg.sender]) {
                    reflectionCut = _rainAmount / 100 * totalFee; 
                }               
            }

            if (!burnExempt[msg.sender]) {
                burnAmount = _rainAmount / 100 * autoBurnPercentage;
            } else if ((!excludedAddresses[msg.sender])) {
                burnAmount = _rainAmount / 100 * autoBurnPercentage;
            }
        }

        // Add total cut with fee and burn exempts included in the calculations
        totalCut = reflectionCut + burnAmount;
        uint256 correctedRain = _rainAmount - totalCut;
        uint256 amountPerSpot = correctedRain / _rainParticipants;

        // Set new rain data
        rainData.rainActive = true;
        rainData.rainAmount = correctedRain;
        rainData.rainSpots = _rainParticipants;
        rainData.rainerAddress = msg.sender;
        rainData.rainToken = address(this);
        rainData.rainAmountPerSpot = amountPerSpot;

        // Transfer tokens
        ERC20 rainToken = ERC20(_rainToken);
        rainToken.transferFrom(msg.sender, address(this), _rainAmount);
    }

    // Function to claim rain
    function claimRain() public {
        require (rainData.rainActive, "ERROR: No rain currently active");
        require (msg.sender != rainData.rainerAddress, "ERROR: Cannot claim from your own rain");

        // Add participant and check if rain slots are filled, if true then [rainActive = false]
        rainData.rainParticipants += 1;
        if (rainData.rainParticipants == rainData.rainSpots) {
            rainData.rainActive = false;

            // Send rain cut to participant
            ERC20 rainToken = ERC20(rainData.rainToken);
            rainToken.transfer(msg.sender, rainData.rainAmountPerSpot);

            // Clear rain data
            rainData.rainAmount = 0;
            rainData.rainSpots = 0;
            rainData.rainerAddress = deadAddress;
            rainData.rainAmountPerSpot = 0;
            rainData.rainParticipants = 0;
        } else {
            // Send rain cut to participant
            ERC20 rainToken = ERC20(rainData.rainToken);
            rainToken.transfer(msg.sender, rainData.rainAmountPerSpot);
        }
    }

    // Function to exclude a receiving address from auto burning
    function addExcludedAddresses(address[] calldata addresses) external onlyRole  (DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < addresses.length; i++) {
            excludedAddresses[addresses[i]] = true;
        }
    }

    // Function to remove an excluded receiving address from auto burn
    function removeExcludedAddresses(address[] calldata addresses) external onlyRole (DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < addresses.length; i++) {
            excludedAddresses[addresses[i]] = false;
        }
    }

    // Returns circulating supply
    function circulatingSupply() public view returns (uint256) {
        uint256 burnedKazama = ERC20.balanceOf(deadAddress) + ERC20.balanceOf(burnAddress);
        uint256 _circulatingSupply = totalSupply() - burnedKazama;
        return _circulatingSupply;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    // Returns current max supply
    function maxSupply() public view returns (uint256) {
        return _maxSupply;
    }

    // Function to burn tokens and update data
    function burn (uint256 _amount) public override {
        IERC20 kazama = IERC20(address(this));

        // Add extra check
        require (kazama.balanceOf(msg.sender) >= _amount, "ERROR: Not enough balance");

        // Update burn data
        totalBurned[msg.sender] = totalBurned[msg.sender] + _amount;
        allTimeBurned = allTimeBurned + _amount;

        // Update [totalSupply]
        _totalSupply = _totalSupply - _amount;

        // Execute
        _burn(msg.sender, _amount);
    }

    // Function to burn from another address and update data
    function burnFrom (address _from, uint256 _amount) public override {
        IERC20 kazama = IERC20(address(this));

        // Add extra check
        require (kazama.balanceOf(_from) >= _amount, "ERROR: Account has not enough balance");

        // Update burn data
        totalBurned[_from] = totalBurned[_from] + _amount;
        allTimeBurned = allTimeBurned + _amount;

        // Update [totalSupply]
        _totalSupply = _totalSupply - _amount;

        // Execute
        _spendAllowance(_from, msg.sender, _amount);
        _burn(_from, _amount);
    }


    // Function to set new max supply
    function setMaxSupply (uint256 _newMaxSupply) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require (_newMaxSupply < MAX_INT, "ERROR: Exceeds max integer");
        require (_newMaxSupply > totalSupply(), "ERROR: Must be more than current totalSupply");
        require (!maxSupplyLocked, "ERROR: Max supply has been locked and therefore immutable");
        _maxSupply = _newMaxSupply;
    }

    // Function to set or revoke burn exampt
    function setBurnExempt (address _account, bool _exempt) public onlyRole(DEFAULT_ADMIN_ROLE) {
        burnExempt[_account] = _exempt;
    }

    // Lock maxSupply (Can be performed once and cannot be reversed)
    function lockMaxSupply() external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxSupplyLocked = true;
    }

    // Mint function
    function mint (uint256 _amount, address _receiver) public onlyRole(MINTER_ROLE) {
        uint256 newSupply = totalSupply() + _amount;
        require (newSupply <= _maxSupply, "ERROR: Exceeds max supply");
        _mint (_receiver, _amount);
    }

    // Internal transfer function with automatic burning and exempt check
    function _transferWithBurn (address _sender, address _recipient, uint256 _amount) internal {
        require(_balances[_sender] >= _amount, "ERROR: Insufficient Balance");

        uint256 burnAmount = 0;

        // Trigger procedure if fees are enabled 
        if (feesEnabled) {
            if (autoSwapActive) {
                return _basicTransfer(_sender, _recipient, _amount);
            }

            if (shouldSwapBack()) {
                executeSwapBack();
            }

            if (shouldAutoBuyback()) {
                triggerAutoBuyback();
            }

            // New uint value to add 
            uint256 correctedAmount = shouldTakeFee(_sender) ? 
            extractFees(_sender, _recipient, _amount) : _amount;

            if (!burnExempt[_sender]) {
                burnAmount = (correctedAmount * autoBurnPercentage) / 100;
                allTimeBurned = allTimeBurned + burnAmount;
                totalBurned[_sender] = totalBurned[_sender] + burnAmount;

            } else if ((!excludedAddresses[_recipient])) {
                burnAmount = (correctedAmount * autoBurnPercentage) / 100;
                allTimeBurned = allTimeBurned + burnAmount;
                totalBurned[_sender] = totalBurned[_sender] + burnAmount;
            }

            if (totalBurned[_sender] > topBurnAmount && _sender != address(this)) {
                topBurnAmount = totalBurned[_sender];
                topBurner = _sender;
            }

            uint256 transferAmount = correctedAmount - burnAmount;
            _burn(_sender, burnAmount);
            super._transfer(_sender, _recipient, transferAmount);

        // Trigger procedure if fees are disabled 
        } else {

            if (!burnExempt[_sender]) {
                burnAmount = (_amount * autoBurnPercentage) / 100;
                allTimeBurned = allTimeBurned + burnAmount;
                totalBurned[_sender] = totalBurned[_sender] + burnAmount;

            } else if ((!excludedAddresses[_recipient])) {
                burnAmount = (_amount * autoBurnPercentage) / 100;
                allTimeBurned = allTimeBurned + burnAmount;
                totalBurned[_sender] = totalBurned[_sender] + burnAmount;
            }

            if (totalBurned[_sender] > topBurnAmount && _sender != address(this)) {
                topBurnAmount = totalBurned[_sender];
                topBurner = _sender;
            }

            uint256 transferAmount = _amount - burnAmount;
            _burn(_sender, burnAmount);
            super._transfer(_sender, _recipient, transferAmount);
        }
    }

    // Regular transfer function when autoSwapActive = [true]
    function _basicTransfer(address _sender, address _recipient, uint256 _amount) internal {
        _balances[_sender] -= _amount;
        _balances[_recipient] += _amount;
    }

    // Transfer function using _transferWithBurn
    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        _transferWithBurn(msg.sender, _recipient, _amount);
        return true;
    }

    // TransferFrom function using _transferWithBurn
    function transferFrom (address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _transferWithBurn(_sender, _recipient, _amount);
        _approve(_sender, msg.sender, allowance(_sender, msg.sender) - _amount);
        return true;
    }

    // Internal to check if the contract can execute a swap
    function shouldSwapBack() internal view returns (bool) {
        return msg.sender != kazamaPair
        && !autoSwapActive
        && autoSwapEnabled
        && _balances[address(this)] >= swapThreshold;
    }

    // Interal to execute the swapback and handle fees
    function executeSwapBack() internal {
        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, liquidityDenominator) ? 0 : liqGeneratorFee;
        uint256 amountToLiquify = swapThreshold * dynamicLiquidityFee / totalFee / 2;
        uint256 amountToSwap = swapThreshold - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;
        uint256 balanceBefore = address(this).balance;

        Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountNative = address(this).balance - balanceBefore;
        uint256 totalNativeFee = totalFee - dynamicLiquidityFee / 2;
        uint256 amountNativeLiquidity = amountNative * dynamicLiquidityFee / totalNativeFee / 2;
        uint256 amountNativeTreasury = amountNative * treasuryFee / totalNativeFee;
        uint256 amountNativeRewards = amountNative * rewardsFee / totalNativeFee;

        try Distributor.deposit {value: amountNativeRewards} () {} catch {}
        payable (zaibatsuHoldings).transfer(amountNativeTreasury);

        if(amountToLiquify > 0){
            Router.addLiquidityETH{value: amountNativeLiquidity}(
                address(this),
                amountToLiquify,
                0,
                0,
                deadAddress,
                block.timestamp
            );
            emit autoLiquify(amountNativeLiquidity, amountToLiquify);
        }
    }

    // Overliquified bool
    function isOverLiquified (uint256 target, uint256 accuracy) public view returns (bool) {
        return getLiquidityBacking(accuracy) > target;
    }

    // Public liquidity backing
    function getLiquidityBacking (uint256 accuracy) public view returns (uint256) {
        return accuracy * (balanceOf(kazamaPair) * 2) / circulatingSupply();
    }

    // Function to take reflection fees
    function extractFees (address sender, address receiver, uint256 amount) internal returns (uint256) {
        uint256 feeAmount = (amount * getTotalFee(receiver == kazamaPair)) / feeDenominator;
        _balances[address(this)] += feeAmount;

        emit Transfer(sender, address(this), feeAmount);
        return amount - feeAmount;
    }

    // Return multiplied fee if buy back is activated
    function getMultipliedFee() public view returns (uint256) {
        if (buyBackMultiplierTriggeredAt + buyBackMultiplierLength > block.timestamp) {
            uint256 remainingTime = buyBackMultiplierTriggeredAt + buyBackMultiplierLength - block.timestamp;
            uint256 feeIncrease = totalFee * buyBackMultiplierNumerator / buyBackMultiplierDenominator - totalFee;
            return totalFee + (feeIncrease * remainingTime) / buyBackMultiplierLength;
        }
        return totalFee;
    }

    // Return total fee
    function getTotalFee (bool selling) public view returns (uint256) {
        if(selling) { 
            return getMultipliedFee();
            }
        return totalFee;
    }

    // Function to edit autoSwap settings
    function editSwapSettings (bool _autoSwapEnabled, uint256 _swapThreshold) external onlyRole (DEFAULT_ADMIN_ROLE) {
        autoSwapEnabled = _autoSwapEnabled;
        swapThreshold = _swapThreshold;
    }

    // Check if fee should be taken depending on if sender is feeExempt [true/false]
    function shouldTakeFee (address _sender) internal view returns (bool) {
        return !isFeeExempt[_sender];
    }

    // Check whether criteria are met to start automatic buyback
    function shouldAutoBuyback() internal view returns (bool) {
        return msg.sender != kazamaPair
        && !autoSwapActive
        && autoBuyBackActive
        && autoBuyBackBlockLast + autoBuyBackBlockPeriod <= block.number
        && address(this).balance >= autoBuyBackAmount;
    }

    // Internal to trigger automatic buyback of KAZAMA tokens
    function triggerAutoBuyback() internal {
        buyKazama(autoBuyBackAmount, burnAddress);
        autoBuyBackBlockLast = block.number;
        autoBuyBackAccumulator += autoBuyBackAmount;

        if (autoBuyBackAccumulator > autoBuyBackCap) {
            autoBuyBackActive = false;
        }
    }

    // Internal that executes the buyback and burns the tokens
    function buyKazama (uint256 amount, address to) internal {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(this);

        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0,
            path,
            to,
            block.timestamp
        );

        _totalSupply -= autoBuyBackAmount;
        allTimeBurned += autoBuyBackAmount;
    }

    // Function to clear stuck balance
    function clearStuckBalance (uint256 _amountPercentage, address _toReceive) external onlyRole (DEFAULT_ADMIN_ROLE) {
        uint256 amountNative = address(this).balance;
        payable(_toReceive).transfer(amountNative * _amountPercentage / 100);
    }

    // Recover or clear stuck third party tokens
    function recoverWrongTokens(address _tokenAddress, address _toReceive, uint256 _tokenAmount) external onlyRole (DEFAULT_ADMIN_ROLE) {
        require(_tokenAddress != address(this), "ERROR: Cannot be KAZAMA token");
        IERC20(_tokenAddress).transfer(address(_toReceive), _tokenAmount);
    }

    // Add or remove reward exempts
    function setIsDividendExempt (address _holder, bool _exempt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_holder != address(this) && _holder != kazamaPair);
        isDividendExempt[_holder] = _exempt;

        if (_exempt){
            Distributor.setShare(_holder, 0);
        } else {
            Distributor.setShare(_holder, _balances[_holder]);
        }
    }

    // Clear buyback multiplier
    function clearBuybackMultiplier() external onlyRole(DEFAULT_ADMIN_ROLE) {
        buyBackMultiplierTriggeredAt = 0;
    }

    // Function to manually trigger the buy back function
    function triggerKazamaBuyback (uint256 _amount, bool _triggerMultiplier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        buyKazama(_amount, burnAddress);

        if (_triggerMultiplier){
            buyBackMultiplierTriggeredAt = block.timestamp;
            emit buyBackMultiplierActive(buyBackMultiplierLength);
        }
    }

    // Increase allowance
    function increaseAllowance (address _spender, uint256 _addedValue) public virtual returns (bool) {
        _approve(msg.sender, _spender, _allowances[msg.sender][_spender] + _addedValue);
        return true;
    }

    // Decrease allowance
    function decreaseAllowance (address _spender, uint256 _subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][_spender];
        require (currentAllowance >= _subtractedValue, "ERC20: decreased allowance below zero");

        unchecked {
            _approve(msg.sender, _spender, currentAllowance - _subtractedValue);
        }
        return true;
    }

    // Set fee exempts
    function setIsFeeExempt (address _holder, bool _exempt) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isFeeExempt[_holder] = _exempt;
    }

    // Function to modify [autoBurnPercentage]
    function editBurnFee (uint256 _autoBurnPercentage) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require (_autoBurnPercentage <= 7 && _autoBurnPercentage > 0, "ERROR [_autoBurnPercentage]: Minimum of 1 and maximum of 7");
        autoBurnPercentage = _autoBurnPercentage;
    }

    // Function to modify [_buyBackBurnFee] + [_liqGeneratorFee] + [_rewardsFee] + [_treasuryFee]
    function editFees (
        uint256 _buyBackBurnFee, 
        uint256 _liqGeneratorFee, 
        uint256 _rewardsFee, 
        uint256 _treasuryFee
        
        ) external onlyRole (DEFAULT_ADMIN_ROLE) {

        // [totalFee] checks
        require (totalFee >= 4, "ERROR: Total fee must be equal to 4 or higher");
        require (totalFee <= 13, "ERROR: Total fee must be equal to 13 or lower");

        // Set new data
        liqGeneratorFee = _liqGeneratorFee;
        buyBackBurnFee = _buyBackBurnFee;
        treasuryFee = _treasuryFee;
        rewardsFee = _rewardsFee;

        totalFee = 
        _liqGeneratorFee + 
        _buyBackBurnFee +
        _treasuryFee +
        _rewardsFee;
    }

    // Function to set distribution data
   function setDistributionCriteria (uint256 _minPeriod, uint256 _minDistribution) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Distributor.setDistributionCriteria (_minPeriod, _minDistribution);
        emit distributionData (_minPeriod, _minDistribution);
    }

    // Function to set new reward token
    function setRewardToken (address _rewardToken) external onlyRole (DEFAULT_ADMIN_ROLE) {
        rewardToken = ERC20(_rewardToken);
        Distributor.setRewardToken(_rewardToken);
        BurnGame.setRewardToken (_rewardToken);
    }

    // Function to set new router
    function setNewRouter (address _newRouter) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Router = KazamaRouter (_newRouter);
        Distributor.setRouter (_newRouter);
    }

    // Function to set burn game generator ranges
    function setGeneratorKeccaks (uint256 _genOne, uint256 _genTwo, uint256 _genThree) external onlyRole (DEFAULT_ADMIN_ROLE) {
        BurnGame.setGeneratorKeccaks (_genOne, _genTwo, _genThree);
    }

    // Function to set the KAZAMA token address in all add-ons
    function setKazamaContract() external onlyRole (DEFAULT_ADMIN_ROLE) {
        BurnGame.setKazamaAddress(address(this));
        Distributor.setKazamaAddress(address(this));
    }

    // Function to set the Senshi NFT address in all add-ons
    function setSenshiNFT (address _senshiNFT) external onlyRole (DEFAULT_ADMIN_ROLE) {
        BurnGame.setSenshiNFT(_senshiNFT);
        Distributor.setSenshiNFT(_senshiNFT);
    }

    // Function to set distributor gas
    function editDistributorGas (uint256 _maxGasAmount) external onlyRole (DEFAULT_ADMIN_ROLE) {
        require(_maxGasAmount < 50000000, "ERROR: Too high");
        distributorGas = _maxGasAmount;
    }

    // Function to (de)activate burn game, add ons included
    function setBurnGameStatus (bool _burnGameActive) external onlyRole (DEFAULT_ADMIN_ROLE) {
        BurnGame.setGameActive(_burnGameActive);
        Distributor.setBurnGameStatus(_burnGameActive);
    }

    // Function to set burn game address to add ons
    function setBurnGameAddress (address _burnGameAddress) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Distributor.setBurnGameAddress(_burnGameAddress);
    }

    // Function to set burn game cut in Distributor
    // [NOTE: Will be by 2, so if 6 is set, cut will be 3]
    function setBurnGameCut (uint256 _burnGameCut) external onlyRole (DEFAULT_ADMIN_ROLE) {
        require (_burnGameCut > 0 && _burnGameCut <= 6, "ERROR: Minimum of 0 and max of 6");
        Distributor.setBurnGameCut(_burnGameCut);
    }

    // Function to set zaibatsu cut in Distributor
    // [NOTE: Will be by 2, so if 6 is set, cut will be 3]
    function setZaibatsuCut (uint256 _zaibatsuCut) external  onlyRole (DEFAULT_ADMIN_ROLE) {
        require (_zaibatsuCut > 0 && _zaibatsuCut <= 6, "ERROR: Minimum of 0 and max of 6");
        Distributor.setZaibatsuCut(_zaibatsuCut);
    }

    // Set zaibatsu holdings
    function setZaibatsuAddress (address _zaibatsuHoldings) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Distributor.setZaibatsuHoldings(_zaibatsuHoldings);
    }

    // Function to (de)activate zaibatsu holdings on add ons
    function setZaibatsuActive (bool _zaibatsuHoldingsActive) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Distributor.setZaibatsuActive(_zaibatsuHoldingsActive);
    }

    // Function to set max amount of senshi nft's
    function editMaxSenshi (uint256 _maxSenshi) external onlyRole (DEFAULT_ADMIN_ROLE) {
        Senshi.editMaxSenshi(_maxSenshi);
    }

    // Function to set senshi price
    function editSenshiPrice (uint256 _senshiPrice) external onlyRole (DEFAULT_ADMIN_ROLE) {
        senshiPrice = _senshiPrice;
    }

    // Function to purchase a senshi nft
    function buySenshi() external {
        require (rewardToken.balanceOf(msg.sender) >= senshiPrice, "ERROR: Not enough balance");
        require (senshiSaleActive, "ERROR: Senshi sale not active");

        senshiNftPurchased[msg.sender] = senshiNftPurchased[msg.sender] + 1;
        rewardToken.transferFrom(msg.sender, zaibatsuHoldings, senshiPrice);

        // Execute senshi purchase
        Senshi.safeMint(msg.sender);
    }
}

contract SenshiNFT is ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl, EIP712, ERC721Votes {

    // General data
    uint256 private nextSenshiId;
    address private kazamaContract;

    uint256 public senshiPrice;
    uint256 public maxSenshi;

    // Senshi mappings
    mapping(uint8 => uint256) public shareBoost;
    mapping(uint8 => uint256) public freeTickets;

    // Just read down
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Only kazama token contract can call these functions
    modifier onlyKazamaContract() {
        require(msg.sender == kazamaContract, "Only the KAZAMA token contract can call this function");
        _;
    }

    // Initiate constructor
    constructor (address _defaultAdmin, address _minter)
        ERC721("Senshi NFT", "SENSHI")
        EIP712("Senshi NFT", "1")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(MINTER_ROLE, _minter);
        kazamaContract = msg.sender;
        maxSenshi = 10000;
    }

    // Function to return baseURI
    function _baseURI() internal pure override returns (string memory) {
        return "https://metadata.kazamaswap.finance/";
    }

    // Internal to assign shareboost to the new senshi minted
    function setShareBoost (uint8 _senshiId, uint256 _shareBoost) internal {
        shareBoost[_senshiId] = _shareBoost;
    }

    // Internal to assign free lottery tickets to the new senshi minted
    function setFreeTickets(uint8 _senshiId, uint256 _freeTickets) internal {
        freeTickets[_senshiId] = _freeTickets;
    }

    // Function to mint a new senshi
    // [NOTE: Only KAZAMA contract has MINTER_ROLE]
    function safeMint (address _to) external onlyRole (MINTER_ROLE) {
        require (nextSenshiId <= maxSenshi, "ERROR: Above max amount of Senshis");

        uint256 senshiId = nextSenshiId ++;
        uint256 generatedShareBooster = assignRewardBoostShare();
        uint256 generatedLotteryTickets = assignFreeLotteryTickets();

        setShareBoost (senshiId, generatedShareBooster);

        _safeMint (_to, senshiId);
    }

    // Generator 1 for free lottery tickets per senshi
    function generatorOneLottery() internal view returns (uint) {
        uint nonce = 0;
        uint genOneLotteryOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 9;
        nonce++;
        return genOneLotteryOutcome;
    }

    // Generator 2 for free lottery tickets per senshi
    function generatorTwoLottery() internal view returns (uint) {
        uint nonce = 0;
        uint genTwoLotteryOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 11;
        genTwoLotteryOutcome = genTwoLotteryOutcome + 3;
        nonce++;
        return genTwoLotteryOutcome;
    }

    // Generator 3 for free lottery tickets per senshi
    function generatorThreeLottery() internal view returns (uint) {
        uint nonce = 0;
        uint genThreeLotteryOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 33;
        genThreeLotteryOutcome  = genThreeLotteryOutcome - 15;
        nonce++;
        return genThreeLotteryOutcome;
    }

    // Free lottery tickets per new minted senshi
    function assignFreeLotteryTickets() internal view returns (uint256) {
        uint256 outcomeOne = generatorOneLottery();
        uint256 outcomeTwo = generatorTwoLottery();
        uint256 outcomeThree = generatorThreeLottery();

        uint256 freeLotteryTickets = outcomeOne + outcomeTwo + outcomeThree;
        return freeLotteryTickets;
    }

    // Generator 1 for reward share boost per senshi
    function generatorOneRewardBoost() internal view returns (uint) {
        uint nonce = 0;
        uint genOneRewardBoost = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 9;
        nonce++;
        return genOneRewardBoost;
    }

    // Generator 2 for reward share boost per senshi
    function generatorTwoRewardBoost() internal view returns (uint) {
        uint nonce = 0;
        uint genTwoRewardBoost = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 11;
        genTwoRewardBoost = genTwoRewardBoost + 3;
        nonce++;
        return genTwoRewardBoost;
    }

    // Generator 3 for reward share boost per senshi
    function generatorThreeRewardBoost() internal view returns (uint) {
        uint nonce = 0;
        uint genThreeRewardBoost = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % 17;
        genThreeRewardBoost = genThreeRewardBoost + 1;
        nonce++;
        return genThreeRewardBoost;
    }

    // Reward share boost per new minted senshi
    function assignRewardBoostShare() internal view returns (uint256) {
        uint256 outcomeOne = generatorOneRewardBoost();
        uint256 outcomeTwo = generatorTwoRewardBoost();
        uint256 outcomeThree = generatorThreeRewardBoost();

        uint256 assignedRewardBoost = outcomeOne + outcomeTwo + outcomeThree;
        return assignedRewardBoost;
    }

    // Set max amount of senshi
    function editMaxSenshi (uint256 _maxSenshi) external onlyKazamaContract {
        maxSenshi = _maxSenshi;
    }

    // Overrides required by Solidity: _update
    function _update (address _to, uint256 _senshiId, address _auth) internal override (ERC721, ERC721Enumerable, ERC721Votes) returns (address) {
        return super._update(_to, _senshiId, _auth);
    }

    // Overrides required by Solidity: _increaseBalance
    function _increaseBalance (address account, uint128 value) internal override (ERC721, ERC721Enumerable, ERC721Votes) {
        super._increaseBalance(account, value);
    }

    // Overrides required by Solidity: tokenURI
    function tokenURI (uint256 tokenId) public view override (ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    // Overrides required by Solidity: supportsInterface
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable, ERC721URIStorage, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

contract KazamaBurnGame is AccessControl {

    // Tokens
    ERC20Burnable public kazamaToken;
    ERC20 public rewardToken;
    ERC721 public senshiNFT;
    address private kazamaContract;

    // General
    bool public gameActive;
    uint256 public minimumReward;
    uint256 public kazamaToBurn;
    uint256 public senshiDiscount;

    uint256 public usdReward;
    uint256 public currentRound;
    uint256 public totalBurnedByGame;
    uint256 public totalRewardedByGame;

    // Keccak ranges
    uint256 private genOneRange;
    uint256 private genTwoRange;
    uint256 private genThreeRange;

    // Last burn data
    address public lastBurner;
    uint256 public lastBurnAmount;
    uint256 public lastUsdReward;

    // Biggest burner data
    address public biggestBurner;
    uint256 public biggestBurnAmount;
    uint256 public biggestBurnReward;

    // Misc
    address public mostTotalBurner;
    uint256 public mostTotalBurned;
    uint256 public mostTotalBurnedRewarded;

    address public mostRewardedBurner;
    uint256 public mostRewardedAmount;
    uint256 public mostRewardedBurned;

    // Player data
    mapping (address => uint256) totalBurned;
    mapping (address => uint256) totalUsdReceived;

    mapping (address => uint256) biggestBurn;
    mapping (address => uint256) biggestUsdReward;

    mapping (address => bool) didBurnPreviousRound;
    mapping (address => bool) senshiNftUsed;
    mapping (address => uint256) burnedPreviousRound;
    mapping (address => uint256) rewardPreviousRound;

    // Only kazama token contract can adjust settings
    modifier onlyKazamaContract() {
        require(msg.sender == kazamaContract, "Only the KAZAMA token contract can call this function");
        _;
    }

    constructor() {
        kazamaContract = msg.sender;
        currentRound = 1;
        senshiDiscount = 33;
        minimumReward = 1 * (10 ** 16);
        kazamaToBurn = 10000 * (10 ** 18);
    }

    // Block hash generators to set a new required amount of kazama to be burned for the new round
    function generatorOne() internal view returns (uint) {
        uint nonce = 0;
        uint genOneOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % genOneRange;
        genOneOutcome = genOneOutcome;
        nonce++;
        return genOneOutcome;
    }

    function generatorTwo() internal view returns (uint) {
        uint nonce = 0;
        uint genTwoOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % genTwoRange;
        genTwoOutcome = genTwoOutcome + 77;
        nonce++;
        return genTwoOutcome;
    }

    function generatorThree() internal view returns (uint) {
        uint nonce = 0;
        uint genThreeOutcome = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % genThreeRange;
        genThreeOutcome = genThreeOutcome;
        nonce++;
        return genThreeOutcome;
    }

    // Generate new amount of kazama to be burned
    function generateNew() internal view returns (uint256) {
        uint256 resultOne = generatorOne();
        uint256 resultTwo = generatorTwo();
        uint256 resultThree = generatorThree();

        uint256 newAmount = resultOne + resultTwo + resultThree;
        return newAmount;
    }

    function claimUSD() public {
        // Checks
        require (gameActive, "GAME ERROR: Game not active");
        require (rewardToken.balanceOf(address(this)) >= minimumReward, "GAME ERROR: Minimum not reached yet");
        require (!didBurnPreviousRound[msg.sender], "GAME ERROR: You claimed last round, wait one round");

        if (senshiNFT.balanceOf(msg.sender) > 0) {
            uint256 discount = kazamaToBurn / 100 * senshiDiscount;
            uint256 newBurnAmount = kazamaToBurn - discount;
            uint256 currentReward = rewardToken.balanceOf(address(this));

            // Reset previous burner data
            didBurnPreviousRound[lastBurner] = false; 

            // Set data
            currentRound += 1;
            totalBurnedByGame = totalBurnedByGame + newBurnAmount;
            totalRewardedByGame = totalRewardedByGame + currentReward;
            lastBurner = msg.sender;
            lastBurnAmount = newBurnAmount;
            lastUsdReward = currentReward;

            // Set mappings
            totalBurned[msg.sender] = totalBurned[msg.sender] + newBurnAmount;
            totalUsdReceived[msg.sender] = totalUsdReceived[msg.sender] + currentReward;
            didBurnPreviousRound[msg.sender] = true;
            senshiNftUsed[msg.sender] = true;
            burnedPreviousRound[msg.sender] = newBurnAmount;
            rewardPreviousRound[msg.sender] = currentReward;           

            // Check if msg.sender has biggest alltime burn
            if (newBurnAmount > biggestBurnAmount) {
                biggestBurner = msg.sender;
                biggestBurnAmount = newBurnAmount;
                biggestBurnReward = currentReward;
            }

            // Check if msg.sender has most burned of every player
            if (totalBurned[msg.sender] > mostTotalBurned) {
                mostTotalBurned = totalBurned[msg.sender];
                mostTotalBurnedRewarded = totalUsdReceived[msg.sender];
                mostTotalBurner = msg.sender;
            }

            // Check if msg.sender has most USD value earned of every player
            if (totalUsdReceived[msg.sender] > mostRewardedAmount) {
                mostRewardedBurner = msg.sender;
                mostRewardedAmount = totalUsdReceived[msg.sender];
                mostRewardedBurned = totalBurned[msg.sender];
            }

            // Execute burn & set new burn amount for next round
            kazamaToken.burnFrom(msg.sender, newBurnAmount);
            kazamaToBurn = generateNew();
        } else {
            uint256 currentReward = rewardToken.balanceOf(address(this));

            // Reset previous burner data
            didBurnPreviousRound[lastBurner] = false; 

            // Set data
            currentRound += 1;
            totalBurnedByGame = totalBurnedByGame + kazamaToBurn;
            totalRewardedByGame = totalRewardedByGame + currentReward;
            lastBurner = msg.sender;
            lastBurnAmount = kazamaToBurn;
            lastUsdReward = currentReward;

            // Set mappings
            totalBurned[msg.sender] = totalBurned[msg.sender] + kazamaToBurn;
            totalUsdReceived[msg.sender] = totalUsdReceived[msg.sender] + currentReward;
            didBurnPreviousRound[msg.sender] = true;
            senshiNftUsed[msg.sender] = false;
            burnedPreviousRound[msg.sender] = kazamaToBurn;
            rewardPreviousRound[msg.sender] = currentReward;           

            // Check if msg.sender has biggest alltime burn
            if (kazamaToBurn > biggestBurnAmount) {
                biggestBurner = msg.sender;
                biggestBurnAmount = kazamaToBurn;
                biggestBurnReward = currentReward;
            }

            // Check if msg.sender has most burned of every player
            if (totalBurned[msg.sender] > mostTotalBurned) {
                mostTotalBurned = totalBurned[msg.sender];
                mostTotalBurnedRewarded = totalUsdReceived[msg.sender];
                mostTotalBurner = msg.sender;
            }

            // Check if msg.sender has most USD value earned of every player
            if (totalUsdReceived[msg.sender] > mostRewardedAmount) {
                mostRewardedBurner = msg.sender;
                mostRewardedAmount = totalUsdReceived[msg.sender];
                mostRewardedBurned = totalBurned[msg.sender];
            }

            // Execute burn & set new burn amount for next round
            kazamaToken.burnFrom(msg.sender, kazamaToBurn);
            kazamaToBurn = generateNew() * 10 ** 18;
        }
    }

    // Function change reward token
    function setRewardToken (address _rewardToken) external onlyKazamaContract {
        rewardToken = ERC20(_rewardToken);
    }

    // Function to set generator keccak ranges
    function setGeneratorKeccaks (uint256 _genOne, uint256 _genTwo, uint256 _genThree) external onlyKazamaContract {
        genOneRange = _genOne;
        genTwoRange = _genTwo;
        genThreeRange = _genThree;
    }

    // Set KAZAMA address
    function setKazamaAddress (address _kazamaAddress) external onlyKazamaContract {
        kazamaToken = ERC20Burnable(_kazamaAddress);
    }

    // Set Senshi NFT address
    function setSenshiNFT (address _senshiNFT) external onlyKazamaContract {
        senshiNFT = ERC721(_senshiNFT);
    }

    // Set game (de)activated
    function setGameActive (bool _gameActive) external onlyKazamaContract {
        gameActive = _gameActive;
    }
}

// Distributor interface
interface IDividendDistributor {
    function setDistributionCriteria (uint256 _minPeriod, uint256 _minDistribution) external;
    function setRewardToken (address _rewardToken) external;
    function setRouter (address _newRouter) external;
    function setShare (address shareholder, uint256 amount) external;
    function deposit () external payable;
    function process (uint256 gas) external;
}

contract DividendDistributor is IDividendDistributor, AccessControl {

    struct Share {
        uint256 amount;
        uint256 totalExcluded;
        uint256 totalRealised;
    }

    ERC20Burnable private kazamaToken;
    ERC721 public senshiNFT;
    ERC20 private rewardToken = ERC20(0x4224d18448b5E88f7d83E053cffB44a9078b05F0);
    KazamaRouter private Router;

    address[] private shareholders;
    address private kazamaAddress;
    address private kazamaContract;
    address private zaibatsuHoldings;
    address private burnGameAddress;
    address private WETH = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;

    mapping(address => uint256) private shareholderIndexes;
    mapping(address => uint256) private shareholderClaims;
    mapping(address => Share) public shares;

    bool public burnGameActive;
    bool public zaibatsuHoldingsActive;

    uint256 public burnGameCut;
    uint256 public totalShares;
    uint256 public totalDividends;
    uint256 public totalDistributed;
    uint256 public dividendsPerShare;
    uint256 public minPeriod = 30 minutes;
    uint256 public minDistribution = 15000 * (10 ** 18);
    uint256 public constant dividendsPerShareAccuracyFactor = 10 ** 36;

    uint256 private currentIndex;
    uint256 private zaibatsuCut;
    bool private initialized;

    modifier initialization() {
        require(!initialized);
        _;
        initialized = true;
    }

    modifier onlyKazamaContract() {
        require(msg.sender == kazamaContract, "ERROR: Only the KAZAMA token contract is allowed");
        _;
    }

    constructor(address _Router) {
        Router = _Router != address(0)
            ? KazamaRouter(_Router)
            : KazamaRouter(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        kazamaContract = msg.sender;
        burnGameCut = 3;
        zaibatsuCut = 3;
    }

    // Function to set distribution criteria
    function setDistributionCriteria (uint256 _minPeriod, uint256 _minDistribution) external override onlyKazamaContract {
        minPeriod = _minPeriod;
        minDistribution = _minDistribution;
    }

    // Function change reward token
    function setRewardToken (address _rewardToken) external override onlyKazamaContract {
        rewardToken = ERC20(_rewardToken);
    }

    // Function to change the router
    function setRouter (address _newRouter) external override onlyKazamaContract {
        Router = KazamaRouter(_newRouter);
    }

    // Set KAZAMA contract
    function setKazamaAddress (address _kazamaToken) external onlyKazamaContract {
        kazamaToken = ERC20Burnable(_kazamaToken);
    }

    // Set Senshi NFT address
    function setSenshiNFT (address _senshiNFT) external onlyKazamaContract {
        senshiNFT = ERC721(_senshiNFT);
    }

    // (De)activate burn game
    function setBurnGameStatus (bool _gameActive) external onlyKazamaContract {
        burnGameActive = _gameActive;
    }

    // Set burn game address
    function setBurnGameAddress (address _burnGameAddress) external onlyKazamaContract {
        burnGameAddress = _burnGameAddress;
    }

    // Set burn game cut
    function setBurnGameCut (uint256 _burnGameCut) external onlyKazamaContract {
        burnGameCut = _burnGameCut;
    }

    // Set zaibatsu cut
    function setZaibatsuCut (uint256 _zaibatsuCut) external onlyKazamaContract {
        zaibatsuCut = _zaibatsuCut;
    }

    // Set zaibatsu address
    function setZaibatsuHoldings (address _zaibatsuHoldings) external onlyKazamaContract {
        zaibatsuHoldings = _zaibatsuHoldings;
    }

    // (De)activate zaibatsu holdings
    function setZaibatsuActive (bool _zaibatsuHoldingsActive) external onlyKazamaContract {
        zaibatsuHoldingsActive = _zaibatsuHoldingsActive;
    }

    // Internal function to add share
    function setShare (address shareholder, uint256 amount) external override onlyKazamaContract {
        if (shares[shareholder].amount > 0) {
            distributeDividend(shareholder);
        }

        if (amount > 0 && shares[shareholder].amount == 0) {
            addShareholder(shareholder);
        } else if (amount == 0 && shares[shareholder].amount > 0) {
            removeShareholder(shareholder);
        }

        totalShares = totalShares - shares[shareholder].amount + amount;
        shares[shareholder].amount = amount;
        shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
    }

    // Function to deposit reward token used by Kazama contract
    function deposit() external payable override onlyKazamaContract {
        uint256 balanceBefore = rewardToken.balanceOf(address(this));

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(rewardToken);

        Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value}(
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amount = rewardToken.balanceOf(address(this)) - balanceBefore;

        totalDividends = totalDividends + amount;
        dividendsPerShare = dividendsPerShare + (dividendsPerShareAccuracyFactor * amount) / totalShares;
    }

    // Function to process
    function process (uint256 gas) external override onlyKazamaContract {
        uint256 shareholderCount = shareholders.length;

        if (shareholderCount == 0) {
            return;
        }

        uint256 gasUsed = 0;
        uint256 gasLeft = gasleft();

        uint256 iterations = 0;

        while (gasUsed < gas && iterations < shareholderCount) {
            if (currentIndex >= shareholderCount) {
                currentIndex = 0;
            }

            if (shouldDistribute(shareholders[currentIndex])) {
                distributeDividend(shareholders[currentIndex]);
            }

            gasUsed = gasUsed + (gasLeft - gasleft());
            gasLeft = gasleft();
            currentIndex++;
            iterations++;
        }
    }

    // Internal function to check if rewards should be distributed
    function shouldDistribute (address shareholder) internal view returns (bool) {
        return shareholderClaims[shareholder] + minPeriod < block.timestamp
            && getUnpaidEarnings(shareholder) > minDistribution;
    }

    // Internal function to distribute rewards
    function distributeDividend (address shareholder) internal {
        if (shares[shareholder].amount == 0) {
            return;
        }

        uint256 amount = getUnpaidEarnings(shareholder);
        uint256 burnGameShare = 0;
        uint256 zaibatsuShare = 0;

        if (amount > 0) {
            if (burnGameActive) {
                burnGameShare = amount / 100 * burnGameCut / 2;
                amount = amount - burnGameShare;
                rewardToken.transfer(burnGameAddress, burnGameShare);
            }

            if (zaibatsuHoldingsActive) {
                zaibatsuShare = amount / 100 * zaibatsuCut / 2;
                amount = amount - zaibatsuShare;
                rewardToken.transfer(zaibatsuHoldings, zaibatsuShare);
            }

            totalDistributed = totalDistributed + amount;
            rewardToken.transfer(shareholder, amount);

            shareholderClaims[shareholder] = block.timestamp;
            shares[shareholder].totalRealised = shares[shareholder].totalRealised + amount;
            shares[shareholder].totalExcluded = getCumulativeDividends(shares[shareholder].amount);
        }
    }

    // Function to claim outstanding rewards
    function claimDividend() external {
        distributeDividend(msg.sender);
    }

    // Function to check outstanding rewards by address
    function getUnpaidEarnings (address shareholder) public view returns (uint256) {
        if (shares[shareholder].amount == 0) {
            return 0;
        }

        uint256 burnGameShare = 0;
        uint256 zaibatsuShare = 0;

        if (burnGameActive) {
            burnGameShare = getCumulativeDividends(shares[shareholder].amount) / 100 * burnGameCut / 2;
        }

        if (zaibatsuHoldingsActive) {
            zaibatsuShare = getCumulativeDividends(shares[shareholder].amount) / 100 * zaibatsuCut / 2;
        }

        uint256 totalCombined = burnGameShare + zaibatsuShare;
        uint256 shareholderTotalDividends = getCumulativeDividends(shares[shareholder].amount);
        uint256 shareholderTotalExcluded = shares[shareholder].totalExcluded;
        shareholderTotalDividends = shareholderTotalDividends - totalCombined;

        if (shareholderTotalDividends <= shareholderTotalExcluded) {
            return 0;
        }

        return shareholderTotalDividends - shareholderTotalExcluded;
    }

    // Internal function to get cumulative rewards
    function getCumulativeDividends (uint256 share) internal view returns (uint256) {
        return (share * dividendsPerShare) / dividendsPerShareAccuracyFactor;
    }

    // Internal function that adds a new shareholder
    function addShareholder (address shareholder) internal {
        shareholderIndexes[shareholder] = shareholders.length;
        shareholders.push(shareholder);
    }

    // Internal function to remove shareholder
    function removeShareholder (address shareholder) internal {
        uint256 indexToRemove = shareholderIndexes[shareholder];
        address lastShareholder = shareholders[shareholders.length - 1];

        shareholders[indexToRemove] = lastShareholder;
        shareholderIndexes[lastShareholder] = indexToRemove;

        shareholders.pop();
    }
}

// Factory interface
interface KazamaFactory {
    function createPair(address tokenA, address tokenB) 
    external returns (address pair);
}

// Router interface
interface KazamaRouter {
    function factory() 
    external pure returns (address);

    function WETH() 
    external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}
