pragma solidity 0.8.17;

import "./LensGoalHelpers.sol";
import "./AutomationCompatible.sol";
import "./AutomationCompatibleInterface.sol";

contract LG is LensGoalHelpers {
    uint256 constant MIN_GOAL_DURATION = 86000;
    address communityWallet = address(0);

    mapping(address => uint256[]) userToGoalEtherStakeIds;
    mapping(address => uint256[]) userToGoalTokenStakeIds;
    mapping(uint256 => GoalEtherStake) goalEtherStakeById;
    mapping(uint256 => GoalTokenStake) goalTokenStakeById;
    uint256 goalEtherStakeId;
    uint256 goalTokenStakeId;
    uint256 lastNonRedistributedGoalEtherStakeId;
    uint256 lastNonRedistributedGoalTokenStakeId;

    struct Votes {
        uint256 yes;
        uint256 no;
    }
    // Goal created with an Ether stake
    struct GoalEtherStake {
        address user;
        string goal;
        string validationCriteria;
        uint256 timestampEnd;
        uint256 etherAmount;
        uint256 id;
        State state;
        Votes votes;
    }
    
    // Goal created with an ERC20 token stake
    struct GoalTokenStake {
        address user;
        string goal;
        string validationCriteria;
        uint256 timestampEnd;
        address tokenAddress;
        uint256 tokenAmount;
        uint256 id;
        State state;
        Votes votes;
    }

    enum State {
        IN_PROCCESS,
        VOTED_FALSE,
        VOTED_TRUE
    }

    event GoalEtherStakeCreated(
        address indexed _user,
        string _goal,
        uint256 _timestampEnd,
        uint256 _etherAmount,
        uint256 _listIndex
    );
    event GoalTokenStakeCreated(
        address indexed _user,
        string _goal,
        uint256 _timestampEnd,
        address indexed _tokenAddress,
        uint256 _tokenAmount,
        uint256 _listIndex
    );

    event GoalEtherStakeVote(
        address indexed _voter,
        bool _vote,
        uint256 _listIndex
    );
    event GoalTokenStakeVote(
        address indexed _voter,
        bool _vote,
        uint256 _listIndex
    );

    function makeGoalEtherStake(
        string memory goalDescription,
        string memory validationCriteria,
        uint256 timestampEnd
    ) external payable {
        require(
            timestampEnd > (block.timestamp + MIN_GOAL_DURATION),
            "goal must end in at least a day after initialization, try again"
        );

        require(
            msg.value > 0,
            "msg.value must be greater than 0"
        );

        uint256 goalId = goalEtherStakeId;

        userToGoalEtherStakeIds[msg.sender].push(goalId);

        goalEtherStakeById[goalId] = GoalEtherStake(
            msg.sender,
            goalDescription,
            validationCriteria,
            timestampEnd,
            msg.value,
            goalId,
            State.IN_PROCCESS,
            Votes(0,0)
        );

        emit GoalEtherStakeCreated(
            msg.sender,
            goalDescription,
            timestampEnd,
            msg.value,
            goalId
        );

        goalEtherStakeId++;
    }

    function makeGoalTokenStake(
        string memory goalDescription,
        string memory validationCriteria,
        uint256 timestampEnd,
        address tokenAddress,
        uint256 tokenAmount
    ) external payable {
        require(
            timestampEnd > (block.timestamp + MIN_GOAL_DURATION),
            "goal must end in at least a day after initialization, try again"
        );

        require(
            tokenAmount > 0,
            "token amount must be greater than 0"
        );

        uint256 goalId = goalTokenStakeId;

        userToGoalTokenStakeIds[msg.sender].push(goalId);

        goalTokenStakeById[goalId] = GoalTokenStake(
            msg.sender,
            goalDescription,
            validationCriteria,
            timestampEnd,
            tokenAddress,
            tokenAmount,
            goalId,
            State.IN_PROCCESS,
            Votes(0,0)
        );

        emit GoalTokenStakeCreated(
            msg.sender,
            goalDescription,
            timestampEnd,
            tokenAddress,
            tokenAmount,
            goalId
        );

        goalTokenStakeId++;
    }

    function voteOnEtherStake(uint256 goalId, bool answer) external {
        // get goal
        GoalEtherStake memory goal = goalEtherStakeById[goalId];
        // get follower nft address
        address followerNFTAddress = getFollowerNFTAddress(goal.user);
        // check if msg.sender is following user (holds nft)
        require(
            IERC721(followerNFTAddress).balanceOf(msg.sender) > 0,
            "you are not following specified user"
        );
        // get end timestamp
        uint256 timestampEnd = goal.timestampEnd;
        // make sure voting window is opened
        require(
            block.timestamp >= timestampEnd &&
                block.timestamp < (timestampEnd + 86400),
            "voting window not opened/closed"
        );
        // add vote
        if(answer){
            goalEtherStakeById[goalId].votes.yes++;
        }else{
            goalEtherStakeById[goalId].votes.no++;
        }
        
        emit GoalEtherStakeVote(msg.sender, answer, goalId);
    }

    function voteOnTokenStake(uint256 goalId, bool answer) external {
        // get goal
        GoalTokenStake memory goal = goalTokenStakeById[goalId];
        // get follower nft address
        address followerNFTAddress = getFollowerNFTAddress(goal.user);
        // check if msg.sender is following user (holds nft)
        require(
            IERC721(followerNFTAddress).balanceOf(msg.sender) > 0,
            "you are not following specified user"
        );
        // get end timestamp
        uint256 timestampEnd = goal.timestampEnd;
        // make sure voting window is opened
        require(
            block.timestamp >= timestampEnd &&
                block.timestamp < (timestampEnd + 86400),
            "voting window not opened/closed"
        );
        // add vote
        if(answer){
            goalTokenStakeById[goalId].votes.yes++;
        }else{
            goalTokenStakeById[goalId].votes.no++;
        }
        
        emit GoalTokenStakeVote(msg.sender, answer, goalId);
    }

     function getGoalEtherStake(
        uint256 goalId
    ) public view returns (GoalEtherStake memory) {
        return goalEtherStakeById[goalId];
    }

    function getGoalTokenStake(
        uint256 goalId
    ) public view returns (GoalTokenStake memory) {
        return goalTokenStakeById[goalId];
    }

    function getGoalEtherStakesByAddress(
        address user
    ) public view returns (GoalEtherStake[] memory) {
        uint256[] memory userGoalIds = userToGoalEtherStakeIds[user];
        uint256 goalCount = userGoalIds.length;
        GoalEtherStake[] memory goalEtherStake = new GoalEtherStake[](goalCount);
        for(uint256 i; i < goalCount; i++){
            goalEtherStake[i] = goalEtherStakeById[userGoalIds[i]];
        }
        return goalEtherStake;
    }

     function checkUpkeep(
        bytes calldata /*checkData */
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // ADD INTERVAL HERE!
        
            GoalEtherStake memory GES = goalEtherStakeById[lastNonRedistributedGoalEtherStakeId];
            if (block.timestamp > (GES.timestampEnd + 1 days)) {
                return (true, bytes("LensGoal"));
            }
            GoalTokenStake memory GTS = goalTokenStakeById[lastNonRedistributedGoalTokenStakeId];
            if (block.timestamp > (GTS.timestampEnd + 1 days)) {
                return (true, bytes("LensGoal"));
            }

        return (false, bytes("LensGoal"));
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // iterate through all items in GoalEtherStakes
        for (uint256 i = lastNonRedistributedGoalEtherStakeId; i <= goalEtherStakeId; i++) {
            // "GES" stands for "Goal Ether Stake"
            GoalEtherStake memory GES = goalEtherStakeById[i];
            // check if voting window expired
            // (60*60*24 seconds is 1 day)
            if (block.timestamp > (GES.timestampEnd + 1 days)) {

                bool result = GES.votes.yes > GES.votes.no;
                // if result is true, ether is sent back to user
                if (result == true) {
                    transferEtherStakeBackToUser(GES);
                }
                if (result == false) {
                    transferEtherStakeToCommunityWallet(GES);
                }
                lastNonRedistributedGoalEtherStakeId++;
            }else{
                break;
            }
        }

        for (uint256 i = lastNonRedistributedGoalTokenStakeId; i <= goalTokenStakeId; i++) {
            // "GTS" stands for "Goal Token Stake"
            GoalTokenStake memory GTS = goalTokenStakeById[i];
            // check if voting window expired
            // (60*60*24 seconds is 1 day)
            if (block.timestamp > (GTS.timestampEnd + 1 days)) {

                bool result = GTS.votes.yes > GTS.votes.no;
                // if result is true, Token is sent back to user
                if (result == true) {
                    transferTokenStakeBackToUser(GTS);
                }
                if (result == false) {
                    transferTokenStakeToCommunityWallet(GTS);
                }
                lastNonRedistributedGoalTokenStakeId++;
            }else{
                break;
            }
        }

       
    }

    function transferEtherStakeBackToUser(GoalEtherStake memory GES) internal {
        payable(GES.user).transfer(GES.etherAmount);
    }

    function transferTokenStakeBackToUser(GoalTokenStake memory GTS) internal {
        IERC20(GTS.tokenAddress).transfer(GTS.user, GTS.tokenAmount);
    }

    function transferEtherStakeToCommunityWallet(
        GoalEtherStake memory GES
    ) internal {
        payable(communityWallet).transfer(GES.etherAmount);
    }

    function transferTokenStakeToCommunityWallet(
        GoalTokenStake memory GTS
    ) internal {
        IERC20(GTS.tokenAddress).transfer(communityWallet, GTS.tokenAmount);
    }

}