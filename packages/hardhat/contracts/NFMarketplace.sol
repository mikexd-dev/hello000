// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFMarketplace is Ownable, IERC721Receiver {
    using SafeMath for uint256;

    // Struct to represent a listing
    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        bool active;
    }

    // Marketplace fee percentage
    uint256 private feePercentage;

    // Mapping of NFT contracts to their respective tokenIds and listings
    mapping(address => mapping(uint256 => Listing)) private listings;

    // Events
    event ListingCreated(address indexed seller, address indexed tokenContract, uint256 indexed tokenId, uint256 price);
    event ListingPriceChanged(address indexed seller, address indexed tokenContract, uint256 indexed tokenId, uint256 price);
    event ListingRemoved(address indexed seller, address indexed tokenContract, uint256 indexed tokenId);
    event ListingSold(address indexed seller, address indexed buyer, address indexed tokenContract, uint256 tokenId, uint256 price);

    constructor() {
        feePercentage = 1; // default fee percentage is set to 1%
    }

    // Function to set the marketplace fee percentage
    function setFeePercentage(uint256 _feePercentage) public onlyOwner {
        require(_feePercentage <= 100, "Invalid percentage");
        feePercentage = _feePercentage;
    }

    // Function to list an NFT for sale
    function listNFT(address _tokenContract, uint256 _tokenId, uint256 _price) public {
        require(_price > 0, "Price must be greater than zero");
        require(_ownsToken(msg.sender, _tokenContract, _tokenId), "You don't own this token");

        Listing storage listing = listings[_tokenContract][_tokenId];

        require(!listing.active, "Token already listed");
        
        listing.seller = msg.sender;
        listing.tokenId = _tokenId;
        listing.price = _price;
        listing.active = true;

        IERC721(_tokenContract).safeTransferFrom(msg.sender, address(this), _tokenId);

        emit ListingCreated(msg.sender, _tokenContract, _tokenId, _price);
    }

    // Function to change the price of a listed NFT
    function changeListingPrice(address _tokenContract, uint256 _tokenId, uint256 _price) public {
        require(_ownsToken(msg.sender, _tokenContract, _tokenId), "You don't own this token");
        
        Listing storage listing = listings[_tokenContract][_tokenId];

        require(listing.active, "Token is not listed");
        require(listing.seller == msg.sender, "You are not the seller");

        listing.price = _price;

        emit ListingPriceChanged(msg.sender, _tokenContract, _tokenId, _price);
    }

    // Function to unlist an NFT
    function unlistNFT(address _tokenContract, uint256 _tokenId) public {
        require(_ownsToken(msg.sender, _tokenContract, _tokenId), "You don't own this token");

        Listing storage listing = listings[_tokenContract][_tokenId];

        require(listing.active, "Token is not listed");
        require(listing.seller == msg.sender, "You are not the seller");

        IERC721(_tokenContract).safeTransferFrom(address(this), msg.sender, _tokenId);

        delete listings[_tokenContract][_tokenId];
        
        emit ListingRemoved(msg.sender, _tokenContract, _tokenId);
    }

    // Function to buy a listed NFT
    function buyNFT(address _tokenContract, uint256 _tokenId) public payable {
        Listing storage listing = listings[_tokenContract][_tokenId];

        require(listing.active, "Token is not listed");
        require(msg.value >= listing.price, "Insufficient funds");
        require(IERC721(_tokenContract).ownerOf(_tokenId) == address(this), "Token is not held by the marketplace");

        // Calculate the marketplace fee
        uint256 fee = listing.price.mul(feePercentage).div(100);

        // Calculate the seller's revenue
        uint256 revenue = listing.price.sub(fee);

        // Transfer the seller's revenue to the seller
        payable(listing.seller).transfer(revenue);

        // Transfer the marketplace fee to the owner
        payable(owner()).transfer(fee);

        // Transfer the NFT to the buyer
        IERC721(_tokenContract).safeTransferFrom(address(this), msg.sender, _tokenId);

        // Deactivate the listing
        listing.active = false;

        emit ListingSold(listing.seller, msg.sender, _tokenContract, _tokenId, listing.price);
    }

    // Function to check if a given address owns a specific token
    function _ownsToken(address _owner, address _tokenContract, uint256 _tokenId) private view returns (bool) {
        return IERC721(_tokenContract).ownerOf(_tokenId) == _owner;
    }

    // Function from ERC721Receiver interface required to accept token transfers
    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // Function to get the details of a listing
    function getListing(address _tokenContract, uint256 _tokenId) public view returns (address, uint256, uint256, bool) {
        Listing storage listing = listings[_tokenContract][_tokenId];

        return (listing.seller, listing.tokenId, listing.price, listing.active);
    }

    // Function to get the marketplace fee percentage
    function getFeePercentage() public view returns (uint256) {
        return feePercentage;
    }
}