// SPDX-License-Identifier: MIT

library Math {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function pow(uint256 a, uint256 b) internal pure returns (uint256) {
        return a**b;
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

interface FrostFlakes {
    function userExists(address adr) external view returns (bool);
}

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract FrostFlakesV5 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    ///@dev no constructor in upgradable contracts. Instead we have initializers
    function initialize() public initializer {
        ///@dev as there is no constructor, we need to initialise the OwnableUpgradeable explicitly
        __Ownable_init();
        _owner = _msgSender();
        FROSTFLAKES_CONTRACT_ADDRESS = 0xAA1E1Ea6E32888A67D37c87FCcd19B5414ac2398;
        ownerAddress = payable(_msgSender());
        MAX_FROST_FLAKES_TIMER = 108000; // 30 hours
        MAX_FROST_FLAKES_AUTOCOMPOUND_TIMER = 518400; // 144 hours / 6 days
        FREEZE_LIMIT_TIMER = 21600; // 6 hours
        BNB_PER_FROSTFLAKE = 6048000000;
        SECONDS_PER_DAY = 86400;
        DAILY_REWARD = 2;
        REQUIRED_FREEZES_BEFORE_DEFROST = 6;
        TEAM_AND_CONTRACT_FEE = 3;
        REF_BONUS = 5;
        FIRST_DEPOSIT_REF_BONUS = 5; // 5 for this bonus + 5 on ref bonus = 10 total on first deposit
        MAX_DEPOSITLINE = 10;
        MIN_DEPOSIT = 50000000000000000; // 0.05 BNB
        BNB_THRESHOLD_FOR_DEPOSIT_REWARD = 5000000000000000000; // 5 BNB
        MAX_PAYOUT = 260000000000000000000; // 260 BNB
        MAX_DEFROST_FREEZE_IN_BNB = 5000000000000000000; // 5 BNB
        MAX_WALLET_TVL_IN_BNB = 250000000000000000000; // 250 BNB
        DEPOSIT_BONUS_REWARD_PERCENT = 10;
        depositAndAirdropBonusEnabled = true;
        requireReferralEnabled = false;
        airdropEnabled = true;
        defrostEnabled = false;
        permanentRewardFromDownlineEnabled = true;
        permanentRewardFromDepositEnabled = true;
        rewardPercentCalculationEnabled = true;
        aHProtocolInitialized = false;
        autoCompoundFeeEnabled = true;
    }

    ///@dev required by the OZ UUPS module
    function _authorizeUpgrade(address) internal override onlyOwner {}

    address internal _owner;
    using Math for uint256;

    struct DetailedReferral {
        address adr;
        uint256 totalDeposit;
        string userName;
        bool hasMigrated;
    }

    address internal FROSTFLAKES_CONTRACT_ADDRESS;
    address internal TEAM_ADDRESS;
    uint256 internal MAX_FROST_FLAKES_TIMER;
    uint256 internal MAX_FROST_FLAKES_AUTOCOMPOUND_TIMER;
    uint256 internal FREEZE_LIMIT_TIMER;
    uint256 internal BNB_PER_FROSTFLAKE;
    uint256 internal SECONDS_PER_DAY;
    uint256 internal DAILY_REWARD;
    uint256 internal REQUIRED_FREEZES_BEFORE_DEFROST;
    uint256 internal TEAM_AND_CONTRACT_FEE;
    uint256 internal REF_BONUS;
    uint256 internal FIRST_DEPOSIT_REF_BONUS;
    uint256 internal MAX_DEPOSITLINE;
    uint256 internal MIN_DEPOSIT;
    uint256 internal BNB_THRESHOLD_FOR_DEPOSIT_REWARD;
    uint256 internal MAX_PAYOUT;
    uint256 internal MAX_DEFROST_FREEZE_IN_BNB;
    uint256 internal MAX_WALLET_TVL_IN_BNB;
    uint256 internal DEPOSIT_BONUS_REWARD_PERCENT;
    uint256 internal TOTAL_USERS;
    bool internal depositAndAirdropBonusEnabled;
    bool internal requireReferralEnabled;
    bool internal airdropEnabled;
    bool internal defrostEnabled;
    bool internal permanentRewardFromDownlineEnabled;
    bool internal permanentRewardFromDepositEnabled;
    bool internal rewardPercentCalculationEnabled;
    bool internal aHProtocolInitialized;
    address payable internal teamAddress;
    address payable internal ownerAddress;
    mapping(address => address) internal sender;
    mapping(address => uint256) internal lockedFrostFlakes;
    mapping(address => uint256) internal lastFreeze;
    mapping(address => uint256) internal lastDefrost;
    mapping(address => uint256) internal firstDeposit;
    mapping(address => uint256) internal freezesSinceLastDefrost;
    mapping(address => bool) internal hasReferred;
    mapping(address => bool) internal migrationRequested;
    mapping(address => uint256) internal lastMigrationRequest;
    mapping(address => bool) internal userInfoMigrated;
    mapping(address => bool) internal userDataMigrated;
    mapping(address => bool) internal isNewUser;
    mapping(address => address) internal upline;
    mapping(address => address[]) internal referrals;
    mapping(address => uint256) internal downLineCount;
    mapping(address => uint256) internal depositLineCount;
    mapping(address => uint256) internal totalDeposit;
    mapping(address => uint256) internal totalPayout;
    mapping(address => uint256) internal airdrops_sent;
    mapping(address => uint256) internal airdrops_sent_count;
    mapping(address => uint256) internal airdrops_received;
    mapping(address => uint256) internal airdrops_received_count;
    mapping(address => string) internal userName;
    mapping(address => bool) internal autoCompoundEnabled;
    mapping(address => uint256) internal autoCompoundStart;
    bool internal autoCompoundFeeEnabled;

    event EmitBoughtFrostFlakes(
        address indexed adr,
        address indexed ref,
        uint256 bnbamount,
        uint256 frostflakesamount
    );
    event EmitFroze(
        address indexed adr,
        address indexed ref,
        uint256 frostflakesamount
    );
    event EmitDeFroze(
        address indexed adr,
        uint256 bnbamount,
        uint256 frostflakesamount
    );
    event EmitAirDropped(
        address indexed adr,
        address indexed reviever,
        uint256 bnbamount,
        uint256 frostflakesamount
    );
    event EmitInitialized(bool initialized);
    event EmitPresaleInitialized(bool initialized);
    event EmitPresaleEnded(bool presaleEnded);
    event EmitMigrationRequested(address investor);
    event EmitMigrationCompleted(address investor);
    event EmitAutoCompounderStart(address investor, uint256 msgValue, uint256 tvl, uint256 fee, bool feeEnabled);

    function isOwner(address adr) public view returns (bool) {
        return adr == _owner;
    }

    function ownerDeposit() public payable onlyOwner {}

    function buyFrostFlakes(address ref) public payable {
        require(aHProtocolInitialized == false, "AH is active");
        require(
            msg.value >= MIN_DEPOSIT,
            "Deposit doesn't meet the minimum requirements"
        );
        require(
            requireReferralEnabled == false ||
                (requireReferralEnabled &&
                    (sender[msg.sender] != address(0) ||
                        sender[ref] != address(0))),
            "Sender or ref must be a current user"
        );
        require(
            totalPayout[msg.sender] < MAX_PAYOUT,
            "Total payout must be lower than max payout"
        );
        require(
            lockedFrostFlakes[msg.sender] <
                calcBuyFrostFlakes(MAX_WALLET_TVL_IN_BNB),
            "Total wallet TVL reached"
        );
        require(
            autoCompoundEnabled[msg.sender] == false,
            "Can't deposit while autocompounding is active"
        );
        require(
            upline[ref] != msg.sender,
            "You are upline of the ref. Ref can therefore not be your upline."
        );

        sender[msg.sender] = msg.sender;

        uint256 marketingFee = calcPercentAmount(
            msg.value,
            TEAM_AND_CONTRACT_FEE
        );
        uint256 bnbValue = Math.sub(msg.value, marketingFee);
        uint256 frostFlakesBought = calcBuyFrostFlakes(bnbValue);

        if (depositAndAirdropBonusEnabled) {
            frostFlakesBought = Math.add(
                frostFlakesBought,
                calcPercentAmount(
                    frostFlakesBought,
                    DEPOSIT_BONUS_REWARD_PERCENT
                )
            );
        }

        uint256 totalFrostFlakesBought = calcMaxLockedFrostFlakes(
            msg.sender,
            frostFlakesBought
        );
        lockedFrostFlakes[msg.sender] = totalFrostFlakesBought;

        uint256 amountToLP = Math.div(bnbValue, 2);

        if (
            !hasReferred[msg.sender] &&
            ref != msg.sender &&
            ref != address(0) &&
            upline[ref] != msg.sender
        ) {
            if (newOrOlduserExists(ref) == false) {
                revert("Referral not found as a user in the system");
            }
            upline[msg.sender] = ref;
            hasReferred[msg.sender] = true;
            referrals[upline[msg.sender]].push(msg.sender);
            downLineCount[upline[msg.sender]] = Math.add(
                downLineCount[upline[msg.sender]],
                1
            );
            if (firstDeposit[msg.sender] == 0 && !isOwner(ref)) {
                uint256 frostFlakesRefBonus = calcPercentAmount(
                    frostFlakesBought,
                    FIRST_DEPOSIT_REF_BONUS
                );
                uint256 totalRefFrostFlakes = calcMaxLockedFrostFlakes(
                    upline[msg.sender],
                    frostFlakesRefBonus
                );
                lockedFrostFlakes[upline[msg.sender]] = totalRefFrostFlakes;
            }
        }

        if (firstDeposit[msg.sender] == 0) {
            firstDeposit[msg.sender] = block.timestamp;
            isNewUser[msg.sender] = true;
            TOTAL_USERS++;
        }

        if (msg.value >= BNB_THRESHOLD_FOR_DEPOSIT_REWARD) {
            depositLineCount[msg.sender] = Math.add(
                depositLineCount[msg.sender],
                Math.div(msg.value, BNB_THRESHOLD_FOR_DEPOSIT_REWARD)
            );
        }

        totalDeposit[msg.sender] = Math.add(
            totalDeposit[msg.sender],
            msg.value
        );

        payable(0x787ef4419cc2fA2633942E42AF602B5a6ED734fd).transfer(
            marketingFee
        );
        ownerAddress.transfer(amountToLP);

        handleFreeze(true);

        emit EmitBoughtFrostFlakes(
            msg.sender,
            ref,
            msg.value,
            frostFlakesBought
        );
    }

    function freeze() public payable {
        require(aHProtocolInitialized == false, "AH is active");
        require(
            totalPayout[msg.sender] < MAX_PAYOUT,
            "Total payout must be lower than max payout"
        );
        require(
            lockedFrostFlakes[msg.sender] <
                calcBuyFrostFlakes(MAX_WALLET_TVL_IN_BNB),
            "Total wallet TVL reached"
        );
        require(canFreeze(), "Now must exceed time limit for next freeze");
        require(
            autoCompoundEnabled[msg.sender] == false,
            "Can't freeze while autocompounding is active"
        );

        handleFreeze(false);
    }

    function calcAutoCompoundReturn(address adr)
        private
        view
        returns (uint256)
    {
        uint256 secondsPassed = Math.sub(
            block.timestamp,
            autoCompoundStart[adr]
        );
        uint256 daysStarted = Math.add(
            1,
            Math.div(secondsPassed, SECONDS_PER_DAY)
        );

        uint256 rewardFactor = Math.pow(102, daysStarted);
        uint256 maxTvlAfterRewards = Math.div(
            Math.mul(rewardFactor, lockedFrostFlakes[adr]),
            Math.pow(10, Math.mul(2, daysStarted))
        );
        uint256 maxRewards = Math.mul(
            Math.sub(maxTvlAfterRewards, lockedFrostFlakes[adr]),
            100000
        );
        uint256 rewardsPerSecond = Math.div(
            maxRewards,
            Math.min(
                Math.mul(SECONDS_PER_DAY, daysStarted),
                MAX_FROST_FLAKES_AUTOCOMPOUND_TIMER
            )
        );
        uint256 currentRewards = Math.mul(
            rewardsPerSecond,
            Math.min(secondsPassed, MAX_FROST_FLAKES_AUTOCOMPOUND_TIMER)
        );
        currentRewards = Math.div(currentRewards, 100000);
        return currentRewards;
    }

    function handleFreeze(bool postDeposit) private {
        uint256 frostFlakes = getFrostFlakesSincelastFreeze(msg.sender);

        if (
            upline[msg.sender] != address(0) && upline[msg.sender] != msg.sender
        ) {
            if ((postDeposit && !isOwner(upline[msg.sender])) || !postDeposit) {
                uint256 frostFlakesRefBonus = calcPercentAmount(
                    frostFlakes,
                    REF_BONUS
                );
                uint256 totalRefFrostFlakes = calcMaxLockedFrostFlakes(
                    upline[msg.sender],
                    frostFlakesRefBonus
                );
                lockedFrostFlakes[upline[msg.sender]] = totalRefFrostFlakes;
            }
        }

        uint256 totalFrostFlakes = calcMaxLockedFrostFlakes(
            msg.sender,
            frostFlakes
        );
        lockedFrostFlakes[msg.sender] = totalFrostFlakes;

        lastFreeze[msg.sender] = block.timestamp;
        freezesSinceLastDefrost[msg.sender] = Math.add(
            freezesSinceLastDefrost[msg.sender],
            1
        );

        emit EmitFroze(msg.sender, upline[msg.sender], frostFlakes);
    }

    function defrost() public payable {
        require(aHProtocolInitialized == false, "AH is active");
        require(defrostEnabled, "Defrost isn't enabled at this moment");
        require(canDefrost(), "Can't defrost at this moment");
        require(
            totalPayout[msg.sender] < MAX_PAYOUT,
            "Total payout must be lower than max payout"
        );
        require(
            autoCompoundEnabled[msg.sender] == false,
            "Can't defrost while autocompounding is active"
        );

        uint256 frostFlakes = getFrostFlakesSincelastFreeze(msg.sender);
        uint256 frostFlakesInBnb = sellFrostFlakes(frostFlakes);

        uint256 marketingAndContractFee = calcPercentAmount(
            frostFlakesInBnb,
            TEAM_AND_CONTRACT_FEE
        );
        frostFlakesInBnb = Math.sub(frostFlakesInBnb, marketingAndContractFee);
        uint256 marketingFee = Math.div(marketingAndContractFee, 2);

        frostFlakesInBnb = Math.sub(frostFlakesInBnb, marketingFee);

        bool totalPayoutHigherThanMax = Math.add(
            totalPayout[msg.sender],
            frostFlakesInBnb
        ) > MAX_PAYOUT;
        if (totalPayoutHigherThanMax) {
            uint256 payout = Math.sub(MAX_PAYOUT, totalPayout[msg.sender]);
            frostFlakesInBnb = payout;
        }

        lastDefrost[msg.sender] = block.timestamp;
        lastFreeze[msg.sender] = block.timestamp;
        freezesSinceLastDefrost[msg.sender] = 0;

        totalPayout[msg.sender] = Math.add(
            totalPayout[msg.sender],
            frostFlakesInBnb
        );

        payable(0x787ef4419cc2fA2633942E42AF602B5a6ED734fd).transfer(
            marketingFee
        );
        payable(msg.sender).transfer(frostFlakesInBnb);

        emit EmitDeFroze(msg.sender, frostFlakesInBnb, frostFlakes);
    }

    function airdrop(address receiver) public payable {
        require(aHProtocolInitialized == false, "AH is active");
        require(airdropEnabled, "Airdrop not Enabled.");

        handleAirdrop(receiver, msg.value);
    }

    function massAirdrop() public payable {
        require(aHProtocolInitialized == false, "AH is active");
        require(airdropEnabled, "Airdrop not Enabled.");
        require(msg.value > 0, "You must state an amount to be airdropped.");

        uint256 sharedAmount = Math.div(
            msg.value,
            referrals[msg.sender].length
        );
        require(sharedAmount > 0, "Shared amount cannot be 0.");

        for (uint256 i = 0; i < referrals[msg.sender].length; i++) {
            address refAdr = referrals[msg.sender][i];
            if (hasMigratedOrIsNewUser(refAdr)) {
                handleAirdrop(refAdr, sharedAmount);
            }
        }
    }

    function handleAirdrop(address receiver, uint256 amount) private {
        require(
            sender[receiver] != address(0),
            "Upline not found as a user in the system"
        );
        require(receiver != msg.sender, "You cannot airdrop yourself");

        uint256 frostFlakesToAirdrop = calcBuyFrostFlakes(amount);

        uint256 marketingAndContractFee = calcPercentAmount(
            frostFlakesToAirdrop,
            TEAM_AND_CONTRACT_FEE
        );
        uint256 frostFlakesMarketingFee = Math.div(marketingAndContractFee, 2);
        uint256 marketingFeeInBnb = calcSellFrostFlakes(
            frostFlakesMarketingFee
        );

        frostFlakesToAirdrop = Math.sub(
            frostFlakesToAirdrop,
            marketingAndContractFee
        );

        if (depositAndAirdropBonusEnabled) {
            frostFlakesToAirdrop = Math.add(
                frostFlakesToAirdrop,
                calcPercentAmount(
                    frostFlakesToAirdrop,
                    DEPOSIT_BONUS_REWARD_PERCENT
                )
            );
        }

        uint256 totalFrostFlakesForReceiver = calcMaxLockedFrostFlakes(
            receiver,
            frostFlakesToAirdrop
        );
        lockedFrostFlakes[receiver] = totalFrostFlakesForReceiver;

        airdrops_sent[msg.sender] = Math.add(
            airdrops_sent[msg.sender],
            Math.sub(amount, calcPercentAmount(amount, TEAM_AND_CONTRACT_FEE))
        );
        airdrops_sent_count[msg.sender] = Math.add(
            airdrops_sent_count[msg.sender],
            1
        );
        airdrops_received[receiver] = Math.add(
            airdrops_received[receiver],
            Math.sub(amount, calcPercentAmount(amount, TEAM_AND_CONTRACT_FEE))
        );
        airdrops_received_count[receiver] = Math.add(
            airdrops_received_count[receiver],
            1
        );

        payable(0x787ef4419cc2fA2633942E42AF602B5a6ED734fd).transfer(
            marketingFeeInBnb
        );

        emit EmitAirDropped(msg.sender, receiver, amount, frostFlakesToAirdrop);
    }

    function updateUpline(address senderToChange, address newUpline)
        public
        payable
        onlyOwner
    {
        require(
            sender[senderToChange] != address(0),
            "SenderToChange not found as a user in the system"
        );
        require(
            sender[newUpline] != address(0),
            "New upline not found as a user in the system"
        );
        upline[senderToChange] = newUpline;
    }

    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        j = _i;
        while (j != 0) {
            bstr[--k] = bytes1(uint8(48 + (j % 10)));
            j /= 10;
        }
        str = string(bstr);
    }

    function enableAutoCompounding() public payable {
        require(canFreeze(), "You need to wait 6 hours between each cycle.");
        uint256 tvl = getUserTLV(msg.sender);
        uint256 fee = 0;
        if (autoCompoundFeeEnabled == true && tvl >= 500000000000000000) {
            fee = Math.div(calcPercentAmount(tvl, 1), 5);
            require(
                msg.value >= fee,
                string.concat(
                    string.concat(
                        string.concat(
                            "msg.value '",
                            string.concat(uint2str(msg.value), "' ")
                        ),
                        "needs to be equal or highter to the fee: "
                    ),
                    uint2str(fee)
                )
            );
            payable(0x787ef4419cc2fA2633942E42AF602B5a6ED734fd).transfer(fee/2);
        }

        handleFreeze(false);
        autoCompoundEnabled[msg.sender] = true;
        autoCompoundStart[msg.sender] = block.timestamp;

        emit EmitAutoCompounderStart(msg.sender, msg.value, tvl, fee, autoCompoundFeeEnabled);
    }

    function disableAutoCompounding() public payable {
        uint256 secondsPassed = Math.sub(
            block.timestamp,
            autoCompoundStart[msg.sender]
        );
        uint256 daysPassed = Math.div(secondsPassed, SECONDS_PER_DAY);
        uint256 freezes = daysPassed;
        if (freezes > 5) {
            freezes = 5;
        }
        if (freezes > 0) {
            freezesSinceLastDefrost[msg.sender] = Math.add(
                freezesSinceLastDefrost[msg.sender],
                freezes
            );
        }
        handleFreeze(false);
        autoCompoundEnabled[msg.sender] = false;
    }

    function requestMigration() public payable {
        require(
            msg.value >= 3500000000000000,
            "Gas fee for migration is too low"
        );
        if (migrationRequested[msg.sender] == false) {
            ownerAddress.transfer(msg.value);
        }
        TOTAL_USERS++;
        migrationRequested[msg.sender] = true;
        lastMigrationRequest[msg.sender] = block.timestamp;
        emit EmitMigrationRequested(msg.sender);
    }

    function reRequestMigration() public payable {
        require(
            migrationRequested[msg.sender] == true,
            "Initial migration request is required"
        );
        require(
            canReRequestMigration(),
            "1 hour must pass between each re-request of migration"
        );
        lastMigrationRequest[msg.sender] = block.timestamp;
        emit EmitMigrationRequested(msg.sender);
    }

    function canReRequestMigration() public view returns (bool) {
        return
            migrationRequested[msg.sender] == true &&
            block.timestamp > Math.add(lastMigrationRequest[msg.sender], 1);
    }

    function migrationCompleted(address userAdr) public payable onlyOwner {
        emit EmitMigrationCompleted(userAdr);
    }

    function migrateUserInfo(
        address user,
        uint256 myLockedFrostFlakes,
        uint256 myConcurrentFreezes,
        uint256 myLastDefrost,
        address[] memory myReferralsList,
        uint256 myLastFreeze,
        uint256 myFirstDeposit
    ) public payable onlyOwner returns (bool) {
        require(
            userInfoMigrated[user] == false,
            "Can't migrate more than once"
        );

        sender[user] = user;

        lastFreeze[user] = myLastFreeze;
        firstDeposit[user] = myFirstDeposit;

        lockedFrostFlakes[user] = myLockedFrostFlakes;
        freezesSinceLastDefrost[user] = myConcurrentFreezes;
        lastDefrost[user] = myLastDefrost;

        for (uint256 i = 0; i < myReferralsList.length; i++) {
            referrals[user].push(myReferralsList[i]);
        }

        userInfoMigrated[user] = true;

        return userInfoMigrated[user];
    }

    function migrateDepositPayoutAndAirdrop(
        address user,
        address myUpline,
        uint256 myReferrals,
        uint256 myTotalDeposit,
        uint256 myTotalPayouts,
        uint256 depositlineExtraReward,
        uint256 myAirdropsSent,
        uint256 myAirdropsSentCount,
        uint256 myAirdropsReceived,
        uint256 myAirdropsReceivedCount
    ) public payable onlyOwner returns (bool) {
        require(
            userDataMigrated[user] == false,
            "Can't migrate more than once"
        );

        depositLineCount[user] = depositlineExtraReward;
        downLineCount[user] = downLineCount[user] + myReferrals;

        totalDeposit[user] = myTotalDeposit;
        totalPayout[user] = myTotalPayouts;

        upline[user] = myUpline;
        if (myUpline != address(0)) {
            hasReferred[user] = true;
        } else {
            hasReferred[user] = false;
        }

        airdrops_sent[user] = myAirdropsSent;
        airdrops_sent_count[user] = myAirdropsSentCount;
        airdrops_received[user] = myAirdropsReceived;
        airdrops_received_count[user] = myAirdropsReceivedCount;

        userDataMigrated[user] = true;
        return userDataMigrated[user];
    }

    function calcMaxLockedFrostFlakes(address adr, uint256 frostFlakesToAdd)
        public
        view
        returns (uint256)
    {
        uint256 totalFrostFlakes = Math.add(
            lockedFrostFlakes[adr],
            frostFlakesToAdd
        );
        uint256 maxLockedFrostFlakes = calcBuyFrostFlakes(
            MAX_WALLET_TVL_IN_BNB
        );
        if (totalFrostFlakes >= maxLockedFrostFlakes) {
            return maxLockedFrostFlakes;
        }
        return totalFrostFlakes;
    }

    function hasMigratedOrIsNewUser(address adr) public view returns (bool) {
        if (userExists(adr) && isNewUser[adr] == true) {
            return true;
        }

        if (
            userExists(adr) &&
            migrationRequested[adr] &&
            userInfoMigrated[adr] &&
            userDataMigrated[adr]
        ) {
            return true;
        }

        return false;
    }

    function setReferralRequirement(bool requireReferral)
        public
        payable
        onlyOwner
        returns (bool)
    {
        requireReferralEnabled = requireReferral;
        return requireReferralEnabled;
    }

    function getReferralRequirement() public view returns (bool) {
        return requireReferralEnabled;
    }

    function enableDefrost() public payable onlyOwner returns (bool) {
        defrostEnabled = true;
        return defrostEnabled;
    }

    function getDefrostEnabled() public view returns (bool) {
        return defrostEnabled;
    }

    function canFreeze() public view returns (bool) {
        uint256 lastAction = lastFreeze[msg.sender];
        if (lastAction == 0) {
            lastAction = firstDeposit[msg.sender];
        }
        return block.timestamp >= Math.add(lastAction, FREEZE_LIMIT_TIMER);
    }

    function canDefrost() public view returns (bool) {
        if (
            lockedFrostFlakes[msg.sender] >=
            calcBuyFrostFlakes(MAX_WALLET_TVL_IN_BNB)
        ) {
            return defrostTimeRequirementReached();
        }
        return
            defrostFreezeRequirementReached() &&
            defrostTimeRequirementReached();
    }

    function defrostTimeRequirementReached() public view returns (bool) {
        uint256 lastDefrostOrFirstDeposit = lastDefrost[msg.sender];
        if (lastDefrostOrFirstDeposit == 0) {
            lastDefrostOrFirstDeposit = firstDeposit[msg.sender];
        }

        if (
            lockedFrostFlakes[msg.sender] >=
            calcBuyFrostFlakes(MAX_WALLET_TVL_IN_BNB)
        ) {
            return block.timestamp >= (lastDefrostOrFirstDeposit + 7 days);
        }

        return block.timestamp >= (lastDefrostOrFirstDeposit + 6 days);
    }

    function defrostFreezeRequirementReached() public view returns (bool) {
        return
            freezesSinceLastDefrost[msg.sender] >=
            REQUIRED_FREEZES_BEFORE_DEFROST;
    }

    function maxPayoutReached(address adr) public view returns (bool) {
        return totalPayout[adr] >= MAX_PAYOUT;
    }

    function getReferrals(address adr)
        public
        view
        returns (address[] memory myReferrals)
    {
        return referrals[adr];
    }

    function getDetailedReferrals(address adr)
        public
        view
        returns (DetailedReferral[] memory myReferrals)
    {
        uint256 resultCount = referrals[adr].length;
        DetailedReferral[] memory result = new DetailedReferral[](resultCount);

        for (uint256 i = 0; i < referrals[adr].length; i++) {
            address refAddress = referrals[adr][i];
            result[i] = DetailedReferral(
                refAddress,
                totalDeposit[refAddress],
                userName[refAddress],
                hasMigratedOrIsNewUser(refAddress)
            );
        }

        return result;
    }

    function getMigrationInfo(address adr)
        public
        view
        returns (
            bool didMigrateInfo,
            bool didMigrateData,
            bool didRequestMigration,
            uint256 didLastRequestMigration
        )
    {
        return (
            userInfoMigrated[adr],
            userDataMigrated[adr],
            migrationRequested[adr],
            lastMigrationRequest[adr]
        );
    }

    function getUserInfo(address adr)
        public
        view
        returns (
            string memory myUserName,
            address myUpline,
            uint256 myReferrals,
            uint256 myTotalDeposit,
            uint256 myTotalPayouts
        )
    {
        return (
            userName[adr],
            upline[adr],
            downLineCount[adr],
            totalDeposit[adr],
            totalPayout[adr]
        );
    }

    function getDepositAndAirdropBonusInfo()
        public
        view
        returns (bool enabled, uint256 bonus)
    {
        return (depositAndAirdropBonusEnabled, DEPOSIT_BONUS_REWARD_PERCENT);
    }

    function getUserAirdropInfo(address adr)
        public
        view
        returns (
            uint256 MyAirdropsSent,
            uint256 MyAirdropsSentCount,
            uint256 MyAirdropsReceived,
            uint256 MyAirdropsReceivedCount
        )
    {
        return (
            airdrops_sent[adr],
            airdrops_sent_count[adr],
            airdrops_received[adr],
            airdrops_received_count[adr]
        );
    }

    function userExists(address adr) public view returns (bool) {
        return sender[adr] != address(0);
    }

    function newOrOlduserExists(address adr) public view returns (bool) {
        if (sender[adr] != address(0)) {
            return true;
        }

        bool isOldUser = FrostFlakes(FROSTFLAKES_CONTRACT_ADDRESS).userExists(
            adr
        );
        if (isOldUser == true) {
            return true;
        }

        return false;
    }

    function getTotalUsers() public view returns (uint256) {
        return TOTAL_USERS;
    }

    function getBnbRewards(address adr) public view returns (uint256) {
        uint256 frostFlakes = getFrostFlakesSincelastFreeze(adr);
        uint256 bnbinWei = sellFrostFlakes(frostFlakes);
        return bnbinWei;
    }

    function getUserTLV(address adr) public view returns (uint256) {
        uint256 bnbinWei = calcSellFrostFlakes(lockedFrostFlakes[adr]);
        return bnbinWei;
    }

    function getUserName(address adr) public view returns (string memory) {
        return userName[adr];
    }

    function setUserName(string memory name)
        public
        payable
        returns (string memory)
    {
        userName[msg.sender] = name;
        return userName[msg.sender];
    }

    function getMyUpline() public view returns (address) {
        return upline[msg.sender];
    }

    function setMyUpline(address myUpline) public payable returns (address) {
        require(upline[msg.sender] == address(0), "Upline already set");
        require(
            sender[msg.sender] != address(0),
            "Upline user does not exists"
        );
        require(
            upline[myUpline] != msg.sender,
            "Cross referencing is not allowed"
        );

        upline[msg.sender] = myUpline;
        hasReferred[msg.sender] = true;
        referrals[upline[msg.sender]].push(msg.sender);
        downLineCount[upline[msg.sender]] = Math.add(
            downLineCount[upline[msg.sender]],
            1
        );

        return upline[msg.sender];
    }

    function getMyTotalDeposit() public view returns (uint256) {
        return totalDeposit[msg.sender];
    }

    function getMyTotalPayout() public view returns (uint256) {
        return totalPayout[msg.sender];
    }

    function togglepPermanentRewardFromDownline(bool enabled)
        public
        payable
        onlyOwner
        returns (bool)
    {
        permanentRewardFromDownlineEnabled = enabled;
        return permanentRewardFromDownlineEnabled;
    }

    function togglepPermanentRewardFromDeposit(bool enabled)
        public
        payable
        onlyOwner
        returns (bool)
    {
        permanentRewardFromDepositEnabled = enabled;
        return permanentRewardFromDepositEnabled;
    }

    function togglepRewardPercentCalculation(bool enabled)
        public
        payable
        onlyOwner
        returns (bool)
    {
        rewardPercentCalculationEnabled = enabled;
        return rewardPercentCalculationEnabled;
    }

    function getToggledValues()
        public
        view
        returns (
            bool permanentRewardFromDownlineToggled,
            bool permanentRewardFromDepositToggled,
            bool airdropToggled,
            bool ahProtocalToggled
        )
    {
        return (
            permanentRewardFromDownlineEnabled,
            permanentRewardFromDepositEnabled,
            airdropEnabled,
            aHProtocolInitialized
        );
    }

    function getAutoCompoundValues()
        public
        view
        returns (bool isAutoCompoundEnabled, uint256 autoCompoundStartValue, bool isAutoCompoundFeeEnabled)
    {
        return (autoCompoundEnabled[msg.sender], autoCompoundStart[msg.sender], autoCompoundFeeEnabled);
    }

    function setBnBThresholdForDepositReward(uint256 newRewardThreshold)
        public
        payable
        onlyOwner
        returns (uint256)
    {
        BNB_THRESHOLD_FOR_DEPOSIT_REWARD = newRewardThreshold;
        return BNB_THRESHOLD_FOR_DEPOSIT_REWARD;
    }

    function getRefBonus() public view returns (uint256) {
        return REF_BONUS;
    }

    function getMarketingAndContractFee() public view returns (uint256) {
        return TEAM_AND_CONTRACT_FEE;
    }

    function getMaxDepositLine() public view returns (uint256) {
        return MAX_DEPOSITLINE;
    }

    function setMaxDepositLine(uint256 newMaxDepositLine)
        public
        payable
        onlyOwner
        returns (uint256)
    {
        MAX_DEPOSITLINE = newMaxDepositLine;
        return MAX_DEPOSITLINE;
    }

    function calcDepositLineBonus(address adr) private view returns (uint256) {
        if (depositLineCount[adr] >= MAX_DEPOSITLINE) {
            return MAX_DEPOSITLINE;
        }

        return depositLineCount[adr];
    }

    function getMyDownlineCount() public view returns (uint256) {
        return downLineCount[msg.sender];
    }

    function getMyDepositLineCount() public view returns (uint256) {
        return depositLineCount[msg.sender];
    }

    function toggleAHProtocol(bool start) public payable onlyOwner {
        aHProtocolInitialized = start;
    }

    function toggleDepositBonus(bool toggled) public payable onlyOwner {
        depositAndAirdropBonusEnabled = toggled;
    }

    function toggleAutoCompoundFee(bool toggled) public payable onlyOwner {
        autoCompoundFeeEnabled = toggled;
    }

    function toggleAirdrops(bool enabled)
        public
        payable
        onlyOwner
        returns (bool)
    {
        airdropEnabled = enabled;
        return airdropEnabled;
    }

    function setDepositBonus(uint256 bonus) public payable onlyOwner {
        if (bonus >= 15) {
            DEPOSIT_BONUS_REWARD_PERCENT = 15;
        } else {
            DEPOSIT_BONUS_REWARD_PERCENT = bonus;
        }
    }

    function calcReferralBonus(address adr) private view returns (uint256) {
        uint256 myReferrals = downLineCount[adr];

        if (myReferrals >= 160) {
            return 10;
        }
        if (myReferrals >= 80) {
            return 9;
        }
        if (myReferrals >= 40) {
            return 8;
        }
        if (myReferrals >= 20) {
            return 7;
        }
        if (myReferrals >= 10) {
            return 6;
        }
        if (myReferrals >= 5) {
            return 5;
        }

        return 0;
    }

    function sellFrostFlakes(uint256 frostFlakes)
        public
        view
        returns (uint256)
    {
        uint256 bnbInWei = calcSellFrostFlakes(frostFlakes);
        bool bnbToSellGreateThanMax = bnbInWei > MAX_DEFROST_FREEZE_IN_BNB;
        if (bnbToSellGreateThanMax) {
            bnbInWei = MAX_DEFROST_FREEZE_IN_BNB;
        }
        return bnbInWei;
    }

    function calcSellFrostFlakes(uint256 frostFlakes)
        internal
        view
        returns (uint256)
    {
        uint256 bnbInWei = Math.mul(frostFlakes, BNB_PER_FROSTFLAKE);
        return bnbInWei;
    }

    function calcBuyFrostFlakes(uint256 bnbInWei)
        public
        view
        returns (uint256)
    {
        uint256 frostFlakes = Math.div(bnbInWei, BNB_PER_FROSTFLAKE);
        return frostFlakes;
    }

    function calcPercentAmount(uint256 amount, uint256 fee)
        private
        pure
        returns (uint256)
    {
        return Math.div(Math.mul(amount, fee), 100);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getConcurrentFreezes(address adr) public view returns (uint256) {
        return freezesSinceLastDefrost[adr];
    }

    function getLastFreeze(address adr) public view returns (uint256) {
        return lastFreeze[adr];
    }

    function getLastDefrost(address adr) public view returns (uint256) {
        return lastDefrost[adr];
    }

    function getFirstDeposit(address adr) public view returns (uint256) {
        return firstDeposit[adr];
    }

    function getLockedFrostFlakes(address adr) public view returns (uint256) {
        return lockedFrostFlakes[adr];
    }

    function getMyExtraRewards()
        public
        view
        returns (uint256 downlineExtraReward, uint256 depositlineExtraReward)
    {
        uint256 extraDownlinePercent = calcReferralBonus(msg.sender);
        uint256 extraDepositLinePercent = calcDepositLineBonus(msg.sender);
        return (extraDownlinePercent, extraDepositLinePercent);
    }

    function updateMigrationStatus(address userAdr, bool migrateValue)
        public
        payable
        onlyOwner
        returns (bool)
    {
        userInfoMigrated[userAdr] = migrateValue;
        userDataMigrated[userAdr] = migrateValue;
        return userInfoMigrated[userAdr] && userDataMigrated[userAdr];
    }

    function getExtraRewards(address adr)
        public
        view
        returns (uint256 downlineExtraReward, uint256 depositlineExtraReward)
    {
        uint256 extraDownlinePercent = calcReferralBonus(adr);
        uint256 extraDepositLinePercent = calcDepositLineBonus(adr);
        return (extraDownlinePercent, extraDepositLinePercent);
    }

    function getExtraBonuses(address adr) private view returns (uint256) {
        uint256 extraBonus = 0;
        if (downLineCount[adr] > 0 && permanentRewardFromDownlineEnabled) {
            uint256 extraRefBonusPercent = calcReferralBonus(adr);
            extraBonus = Math.add(extraBonus, extraRefBonusPercent);
        }
        if (depositLineCount[adr] > 0 && permanentRewardFromDepositEnabled) {
            uint256 extraDepositLineBonusPercent = calcDepositLineBonus(adr);
            extraBonus = Math.add(extraBonus, extraDepositLineBonusPercent);
        }
        return extraBonus;
    }

    function getFrostFlakesSincelastFreeze(address adr)
        public
        view
        returns (uint256)
    {
        uint256 maxFrostFlakes = MAX_FROST_FLAKES_TIMER;
        uint256 lastFreezeOrFirstDeposit = lastFreeze[adr];
        if (lastFreeze[adr] == 0) {
            lastFreezeOrFirstDeposit = firstDeposit[adr];
        }

        uint256 secondsPassed = Math.min(
            maxFrostFlakes,
            Math.sub(block.timestamp, lastFreezeOrFirstDeposit)
        );

        uint256 frostFlakes = calcFrostFlakesReward(
            secondsPassed,
            DAILY_REWARD,
            adr
        );

        if (autoCompoundEnabled[adr]) {
            frostFlakes = calcAutoCompoundReturn(adr);
        }

        uint256 extraBonus = getExtraBonuses(adr);
        if (extraBonus > 0) {
            uint256 extraBonusFrostFlakes = calcPercentAmount(
                frostFlakes,
                extraBonus
            );
            frostFlakes = Math.add(frostFlakes, extraBonusFrostFlakes);
        }

        return frostFlakes;
    }

    function calcFrostFlakesReward(
        uint256 secondsPassed,
        uint256 dailyReward,
        address adr
    ) private view returns (uint256) {
        uint256 rewardsPerDay = calcPercentAmount(
            Math.mul(lockedFrostFlakes[adr], 100000),
            dailyReward
        );
        uint256 rewardsPerSecond = Math.div(rewardsPerDay, SECONDS_PER_DAY);
        uint256 frostFlakes = Math.mul(rewardsPerSecond, secondsPassed);
        frostFlakes = Math.div(frostFlakes, 100000);
        return frostFlakes;
    }
}
