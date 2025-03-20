// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
}

// Use TimeUnit and CommitReveal contracts properly
import "./TimeUnit.sol";
import "./CommitReveal.sol";

contract RPSLS {
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public timeoutMinutes = 5; // Timeout set to 5 minutes

    mapping(address => uint) public player_choice; // 0 - Rock, 1 - Scissors, 2 - Paper, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    mapping(address => bool) public player_committed;  // Track if player has committed

    address[] public players;
    uint public numInput = 0;
    IERC20 public token;
    TimeUnit public timeUnit;
    CommitReveal public commitReveal;

    // Constructor with proper initialization of TimeUnit and CommitReveal contracts
    constructor(address _token, address _commitReveal) {
        token = IERC20(_token); // Initialize ERC20 token interface
        timeUnit = new TimeUnit(); // Initialize the TimeUnit contract
        commitReveal = CommitReveal(_commitReveal); // Initialize the CommitReveal contract with the provided address
    }

    function addPlayer() public {
        require(numPlayer < 2, "Game full.");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "Already joined.");
        }
        numPlayer++;
        players.push(msg.sender);
        player_not_played[msg.sender] = true;

        // Approve contract to withdraw funds from players' accounts
        require(token.allowance(msg.sender, address(this)) >= 0.000001 ether, "Allowance not set.");
        player_committed[msg.sender] = true;

        // Transfer the 0.000001 ether (or equivalent token) from player to contract
        require(token.transferFrom(msg.sender, address(this), 0.000001 ether), "Transfer failed.");

        if (numPlayer == 2) {
            timeUnit.setStartTime();
        }
    }

    function input(uint choice) public {
        require(numPlayer == 2, "Need 2 players.");
        require(player_not_played[msg.sender], "Already played.");
        require(choice >= 0 && choice <= 4, "Invalid choice.");
        
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;

        if (numInput == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        if (_isWinner(p0Choice, p1Choice)) {
            account0.transfer(reward);
        } 
        else if (_isWinner(p1Choice, p0Choice)) {
            account1.transfer(reward);
        } 
        else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        _resetGame();
    }

    function claimWinDueToTimeout() public {
        require(numPlayer == 2, "Game not started.");
        require(timeUnit.hasTimedOut(timeoutMinutes), "Not timed out yet.");

        if (player_not_played[players[0]]) {
            address payable winner = payable(players[1]);
            winner.transfer(reward);
        }
        else if (player_not_played[players[1]]) {
            address payable winner = payable(players[0]);
            winner.transfer(reward);
        }

        _resetGame();
    }

    function claimRewardIfPlayer1DoesNotJoin() public {
        require(numPlayer == 1, "Player 1 must not join the game.");
        address payable winner = payable(players[0]);
        winner.transfer(reward);
        _resetGame();
    }

    function claimRewardIfPlayer1DoesNotMakeChoice() public {
        require(numPlayer == 2, "Need 2 players.");
        require(player_not_played[players[1]], "Player 1 has made their choice.");

        address payable winner = payable(players[0]);
        winner.transfer(reward);

        _resetGame();
    }

    function _resetGame() private {
        delete players;
        numPlayer = 0;
        numInput = 0;
        reward = 0;
        timeUnit.setStartTime();
    }

    function _isWinner(uint choiceA, uint choiceB) private pure returns (bool) {
        return (
            (choiceA == 0 && (choiceB == 1 || choiceB == 3)) || // Rock crushes Scissors & Lizard
            (choiceA == 1 && (choiceB == 2 || choiceB == 3)) || // Scissors cuts Paper & decapitates Lizard
            (choiceA == 2 && (choiceB == 0 || choiceB == 4)) || // Paper covers Rock & disproves Spock
            (choiceA == 3 && (choiceB == 2 || choiceB == 4)) || // Lizard eats Paper & poisons Spock
            (choiceA == 4 && (choiceB == 0 || choiceB == 1))    // Spock vaporizes Rock & smashes Scissors
        );
    }
}
