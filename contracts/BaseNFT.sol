// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title BaseNFT
 * @dev Advanced NFT contract optimized for Base blockchain
 * @author Base Builders Community
 */
contract BaseNFT is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    // State variables
    Counters.Counter private _tokenIds;
    string private _baseTokenURI;
    uint256 public maxSupply;
    uint256 public mintPrice;
    uint256 public maxMintPerAddress;
    bool public publicMintEnabled;
    bool public whitelistMintEnabled;
    
    // Mapping for whitelist
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public mintedCount;
    
    // Events
    event TokenMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event WhitelistUpdated(address indexed account, bool status);
    event PublicMintToggled(bool enabled);
    event WhitelistMintToggled(bool enabled);
    event BaseURIUpdated(string newBaseURI);
    event MintPriceUpdated(uint256 newPrice);

    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param _maxSupply Maximum supply of tokens
     * @param _mintPrice Price per token in wei
     * @param _maxMintPerAddress Maximum tokens per address
     * @param baseURI Base URI for token metadata
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        uint256 _mintPrice,
        uint256 _maxMintPerAddress,
        string memory baseURI
    ) ERC721(name, symbol) {
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        maxMintPerAddress = _maxMintPerAddress;
        _baseTokenURI = baseURI;
        publicMintEnabled = false;
        whitelistMintEnabled = false;
    }

    /**
     * @dev Public mint function
     * @param quantity Number of tokens to mint
     */
    function publicMint(uint256 quantity) external payable nonReentrant {
        require(publicMintEnabled, "Public mint not enabled");
        require(quantity > 0, "Quantity must be greater than 0");
        require(_tokenIds.current() + quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _mintTokens(msg.sender, quantity);
    }

    /**
     * @dev Whitelist mint function
     * @param quantity Number of tokens to mint
     */
    function whitelistMint(uint256 quantity) external payable nonReentrant {
        require(whitelistMintEnabled, "Whitelist mint not enabled");
        require(whitelist[msg.sender], "Not whitelisted");
        require(quantity > 0, "Quantity must be greater than 0");
        require(_tokenIds.current() + quantity <= maxSupply, "Exceeds max supply");
        require(mintedCount[msg.sender] + quantity <= maxMintPerAddress, "Exceeds max mint per address");
        require(msg.value >= mintPrice * quantity, "Insufficient payment");

        _mintTokens(msg.sender, quantity);
    }

    /**
     * @dev Owner mint function (free minting for owner)
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function ownerMint(address to, uint256 quantity) external onlyOwner {
        require(quantity > 0, "Quantity must be greater than 0");
        require(_tokenIds.current() + quantity <= maxSupply, "Exceeds max supply");

        _mintTokens(to, quantity);
    }

    /**
     * @dev Internal mint function
     * @param to Address to mint to
     * @param quantity Number of tokens to mint
     */
    function _mintTokens(address to, uint256 quantity) internal {
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();
            _safeMint(to, newTokenId);
            
            string memory tokenURI = string(abi.encodePacked(_baseTokenURI, newTokenId.toString(), ".json"));
            _setTokenURI(newTokenId, tokenURI);
            
            emit TokenMinted(to, newTokenId, tokenURI);
        }
        
        mintedCount[to] += quantity;
    }

    /**
     * @dev Add addresses to whitelist
     * @param addresses Array of addresses to whitelist
     */
    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = true;
            emit WhitelistUpdated(addresses[i], true);
        }
    }

    /**
     * @dev Remove addresses from whitelist
     * @param addresses Array of addresses to remove
     */
    function removeFromWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            whitelist[addresses[i]] = false;
            emit WhitelistUpdated(addresses[i], false);
        }
    }

    /**
     * @dev Toggle public mint
     */
    function togglePublicMint() external onlyOwner {
        publicMintEnabled = !publicMintEnabled;
        emit PublicMintToggled(publicMintEnabled);
    }

    /**
     * @dev Toggle whitelist mint
     */
    function toggleWhitelistMint() external onlyOwner {
        whitelistMintEnabled = !whitelistMintEnabled;
        emit WhitelistMintToggled(whitelistMintEnabled);
    }

    /**
     * @dev Update base URI
     * @param newBaseURI New base URI
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    /**
     * @dev Update mint price
     * @param newPrice New mint price in wei
     */
    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    /**
     * @dev Withdraw contract balance
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    /**
     * @dev Get total supply
     */
    function totalSupply() public view override returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev Get base URI
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Check if token exists
     * @param tokenId Token ID to check
     */
    function exists(uint256 tokenId) external view returns (bool) {
        return _exists(tokenId);
    }

    /**
     * @dev Get tokens owned by address
     * @param owner Address to query
     */
    function tokensOfOwner(address owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        
        return tokenIds;
    }

    // Required overrides
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
