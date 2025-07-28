// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DecentralizedLottery {
    address public owner;
    address[] public players;
    address public winner;
    uint256 public lotteryId;
    uint256 public ticketPrice;
    uint256 public maxPlayers;
    bool public lotteryActive;
    
    mapping(uint256 => address) public lotteryHistory;
    
    event PlayerEntered(address indexed player, uint256 lotteryId);
    event WinnerSelected(address indexed winner, uint256 prize, uint256 lotteryId);
    event LotteryStarted(uint256 lotteryId, uint256 ticketPrice, uint256 maxPlayers);
    event LotteryEnded(uint256 lotteryId);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier lotteryIsActive() {
        require(lotteryActive, "Lottery is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        lotteryId = 1;
        lotteryActive = false;
    }
    
    // 1. Start a new lottery round
    function startLottery(uint256 _ticketPrice, uint256 _maxPlayers) external onlyOwner {
        require(!lotteryActive, "Lottery is already active");
        require(_ticketPrice > 0, "Ticket price must be greater than 0");
        require(_maxPlayers >= 2, "Must allow at least 2 players");
        
        ticketPrice = _ticketPrice;
        maxPlayers = _maxPlayers;
        lotteryActive = true;
        delete players; // Clear previous players
        
        emit LotteryStarted(lotteryId, ticketPrice, maxPlayers);
    }
    
    // 2. Enter the lottery by buying a ticket
    function enterLottery() external payable lotteryIsActive {
        require(msg.value == ticketPrice, "Incorrect ticket price");
        require(players.length < maxPlayers, "Lottery is full");
        require(!isPlayerEntered(msg.sender), "Player already entered");
        
        players.push(msg.sender);
        
        emit PlayerEntered(msg.sender, lotteryId);
        
        // Automatically pick winner when lottery is full
        if (players.length == maxPlayers) {
            pickWinner();
        }
    }
    
    // 3. Pick winner using verifiable randomness
    function pickWinner() public onlyOwner lotteryIsActive {
        require(players.length >= 2, "Not enough players to pick winner");
        
        // Generate pseudo-random number using block properties
        // Note: In production, use Chainlink VRF for true randomness
        uint256 randomIndex = generateRandomNumber() % players.length;
        winner = players[randomIndex];
        
        // Calculate prize (90% to winner, 10% to contract owner as fee)
        uint256 totalPrize = address(this).balance;
        uint256 winnerPrize = (totalPrize * 90) / 100;
        uint256 ownerFee = totalPrize - winnerPrize;
        
        // Store winner in history
        lotteryHistory[lotteryId] = winner;
        
        // Transfer prizes
        payable(winner).transfer(winnerPrize);
        payable(owner).transfer(ownerFee);
        
        emit WinnerSelected(winner, winnerPrize, lotteryId);
        
        // End current lottery
        lotteryActive = false;
        lotteryId++;
        
        emit LotteryEnded(lotteryId - 1);
    }
    
    // 4. Get current lottery information
    function getLotteryInfo() external view returns (
        uint256 currentLotteryId,
        uint256 currentTicketPrice,
        uint256 currentMaxPlayers,
        uint256 currentPlayerCount,
        uint256 prizePool,
        bool isActive
    ) {
        return (
            lotteryId,
            ticketPrice,
            maxPlayers,
            players.length,
            address(this).balance,
            lotteryActive
        );
    }
    
    // 5. Get all current players
    function getPlayers() external view returns (address[] memory) {
        return players;
    }
    
    // 6. Check if a specific address has entered the current lottery
    function isPlayerEntered(address player) public view returns (bool) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return true;
            }
        }
        return false;
    }
    
    // Internal function to generate pseudo-random number
    function generateRandomNumber() private view returns (uint256) {
        return uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    block.number,
                    players.length,
                    msg.sender
                )
            )
        );
    }
    
    // Get winner of a specific lottery
    function getLotteryWinner(uint256 _lotteryId) external view returns (address) {
        return lotteryHistory[_lotteryId];
    }
    
    // Emergency function to withdraw funds (only owner)
    function emergencyWithdraw() external onlyOwner {
        require(!lotteryActive, "Cannot withdraw during active lottery");
        payable(owner).transfer(address(this).balance);
    }
}
