// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

// for testing
// subscriptionId: 46028468953454012881341962962912460145529398899847134984409356391396909394706
// vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B
// keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae

contract NFTArena is 
    ERC721URIStorage, 
    ReentrancyGuard, 
    Ownable,
    VRFConsumerBaseV2
{
    VRFCoordinatorV2Interface COORDINATOR;
    uint256 s_subscriptionId;
    bytes32 keyHash;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    uint256 private _tokenIds;
    uint256 private _itemsSold;
    uint256 public mintingPrice = 0.00000001 ether;

    uint256 public totalETHStaked;
    uint256 public battleId;
    mapping(uint256 => uint256) private s_requestIdToBattleId;
    mapping(uint256 => bool) private s_battlePending;

    enum NFTCategory { Artwork, Video, GIF }

    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
        NFTCategory category;
    }

    struct BattleEntry {
        address player;
        uint256 tokenId;
        string name;
    }

    struct BattleWinnerDetails {
        address winner;
        uint256 tokenId;
        string category;
        string tokenURI;
        uint256 reward;
    }

    mapping(uint256 => ListedToken) private idToListedToken;
    mapping(uint256 => BattleEntry[]) public battles;
    mapping(uint256 => BattleWinnerDetails) public battleWinners;
    mapping(uint256 => mapping(address => bool)) public hasEnteredBattle;

    event TokenListedSuccess(
        uint256 indexed tokenId,
        address owner,
        address seller,
        uint256 price,
        bool currentlyListed,
        NFTCategory category
    );

    event BattleEntered(
        address indexed player, 
        uint256 tokenId, 
        string category
    );

    event BattleWinnerDeclared(
        address indexed winner, 
        uint256 tokenId, 
        string category, 
        string tokenURI, 
        uint256 reward
    );

    event RandomnessRequested(
        uint256 indexed requestId, 
        uint256 indexed battleId
    );

    constructor(uint256 subscriptionId, address vrfCoordinator, bytes32 _keyHash) 
        ERC721("NFTMarketplace", "NFTM") 
        VRFConsumerBaseV2(vrfCoordinator)
        Ownable(msg.sender)
    {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
    }

    function updateMintingPrice(uint256 _listPrice) public onlyOwner {
        mintingPrice = _listPrice;
    }

    function getMintingPrice() public view returns (uint256) {
        return mintingPrice;
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds;
    }

    function mintToken(
        string memory tokenURI, 
        NFTCategory category
    ) public payable nonReentrant returns (uint256) {
        require(msg.value >= mintingPrice, "Not enough ETH to mint!");

        _tokenIds++;
        uint256 newTokenId = _tokenIds;

        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        idToListedToken[newTokenId] = ListedToken(
            newTokenId,
            payable(msg.sender),
            payable(address(0)),
            0,
            false,
            category
        );

        return newTokenId;
    }

    function createListedToken(
        uint256 tokenId, 
        uint256 price
    ) public nonReentrant {
        require(price > 0, "Price must be greater than zero");
        require(ownerOf(tokenId) == msg.sender, "You must own the NFT to list it");

        idToListedToken[tokenId].owner = payable(address(this));
        idToListedToken[tokenId].seller = payable(msg.sender);
        idToListedToken[tokenId].price = price;
        idToListedToken[tokenId].currentlyListed = true;

        _transfer(msg.sender, address(this), tokenId);

        emit TokenListedSuccess(
            tokenId,
            address(this),
            msg.sender,
            price,
            true,
            idToListedToken[tokenId].category
        );
    }

    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint256 nftCount = _tokenIds;
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        
        for (uint256 i = 1; i <= nftCount; i++) {
            tokens[i-1] = idToListedToken[i];
        }
        return tokens;
    }

    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint256 totalItemCount = _tokenIds;
        uint256 itemCount = 0;

        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (idToListedToken[i].owner == msg.sender || idToListedToken[i].seller == msg.sender) {
                itemCount++;
            }
        }

        ListedToken[] memory items = new ListedToken[](itemCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 1; i <= totalItemCount; i++) {
            if (idToListedToken[i].owner == msg.sender || 
                idToListedToken[i].seller == msg.sender) {
                items[currentIndex] = idToListedToken[i];
                currentIndex++;
            }
        }
        return items;
    }

    function executeSale(uint256 tokenId) public payable nonReentrant {
        ListedToken storage item = idToListedToken[tokenId];
        require(item.currentlyListed, "NFT not listed for sale");
        require(msg.value == item.price, "Incorrect price sent");

        address seller = item.seller;
        item.currentlyListed = false;
        item.owner = payable(msg.sender);
        item.seller = payable(address(0));
        _itemsSold++;

        _transfer(address(this), msg.sender, tokenId);

        payable(owner()).transfer(mintingPrice);
        payable(seller).transfer(msg.value - mintingPrice);
    }

    function enterBattle(uint256 tokenId) public payable nonReentrant {
        require(msg.value > 0, "Must send some ETH to enter");
        require(ownerOf(tokenId) == msg.sender, "You must own this NFT");
        require(!hasEnteredBattle[battleId][msg.sender], "Already entered this battle");
        require(!s_battlePending[battleId], "Battle winner selection in progress");

        NFTCategory category = idToListedToken[tokenId].category;
        string memory categoryName = _getCategoryName(category);

        totalETHStaked += msg.value;

        battles[battleId].push(BattleEntry({
            player: msg.sender,
            tokenId: tokenId,
            name: categoryName
        }));

        hasEnteredBattle[battleId][msg.sender] = true;
        emit BattleEntered(msg.sender, tokenId, categoryName);
    }

    // Real Chainlink VRF request function
    function requestRandomWinner() public onlyOwner returns (uint256 requestId) {
        require(battles[battleId].length > 1, "Not enough players");
        require(!s_battlePending[battleId], "Random number already requested");

        s_battlePending[battleId] = true;
        
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            uint64(s_subscriptionId),
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        
        s_requestIdToBattleId[requestId] = battleId;
        
        emit RandomnessRequested(requestId, battleId);
        
        return requestId;
    }

    // Chainlink VRF callback function
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 currentBattleId = s_requestIdToBattleId[requestId];
        uint256 randomNumber = randomWords[0];
        
        _declareWinner(currentBattleId, randomNumber);
    }

    function _declareWinner(uint256 _battleId, uint256 randomNumber) private {
        uint256 winnerIndex = randomNumber % battles[_battleId].length;
        BattleEntry memory winner = battles[_battleId][winnerIndex];

        uint256 reward = (totalETHStaked * 70) / 100;
        uint256 ownerCut = totalETHStaked - reward;

        string memory uri = tokenURI(winner.tokenId);

        battleWinners[_battleId] = BattleWinnerDetails({
            winner: winner.player,
            tokenId: winner.tokenId,
            category: winner.name,
            tokenURI: uri,
            reward: reward
        });

        payable(winner.player).transfer(reward);
        payable(owner()).transfer(ownerCut);

        emit BattleWinnerDeclared(
            winner.player, 
            winner.tokenId, 
            winner.name, 
            uri, 
            reward
        );

        s_battlePending[_battleId] = false;
        battleId++;
        totalETHStaked = 0;
    }

    function getBattleEntries(uint256 _battleId) public view returns (BattleEntry[] memory) {
        return battles[_battleId];
    }

    function getWinnerDetails(uint256 _battleId) public view returns (BattleWinnerDetails memory) {
        return battleWinners[_battleId];
    }

    function getCurrentBattleId() public view returns (uint256) {
        return battleId;
    }

    function isBattlePending(uint256 _battleId) public view returns (bool) {
        return s_battlePending[_battleId];
    }

    function _getCategoryName(NFTCategory category) internal pure returns (string memory) {
        if (category == NFTCategory.Artwork) return "Artwork";
        if (category == NFTCategory.Video) return "Video";
        if (category == NFTCategory.GIF) return "GIF";
        return "Unknown";
    }

    function updateVRFConfig(
        uint256 subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations
    ) public onlyOwner {
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getTotalItemsSold() public view returns (uint256) {
        return _itemsSold;
    }

    function getTotalETHStaked() public view returns (uint256) {
        return totalETHStaked;
    }

    // Keep the test function for manual testing
    function testDeclareWinner(uint256 _battleId, uint256 mockRandomNumber) public onlyOwner {
        _declareWinner(_battleId, mockRandomNumber);
    }

    receive() external payable {}
    fallback() external payable {}
}