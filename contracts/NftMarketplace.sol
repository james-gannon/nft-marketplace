// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
error NftMarketplace__NoProceeds();
error NftMarketplace__TransferFailed();

contract NftMarketplace is ReentrancyGuard {
    /**
     * Define Listing struct
     */
    struct Listing {
        uint256 price;
        address seller;
    }

    event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

    event ItemCanceled(address indexed seller, address indexed nftAddress, uint256 tokenId);

    /**
     * NFT Contract adress, mapped to NFT TokenID, mapped to Listing
     */
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    /**
     * Keep track of proceeds earn from users selling NFs
     */
    mapping(address => uint256) private s_proceeds;

    // constructor() {}

    /**
     * =============================================================
     * MODIFIERS
     * =============================================================
     */

    /**
     * Make sure we cannot re-list, listed NFTs
     */
    modifier notListed(
        address nftAddress,
        uint256 tokenId,
        address owner
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }

    /**
     * Verify that only owners of the NFT can actually list it
     */
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        IERC721 nft = IERC721(nftAddress);
        address owner = nft.ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketplace__NotOwner();
        }
        _;
    }

    /**
     * isListed
     */
    modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price <= 0) {
            revert NftMarketplace__NotListed(nftAddress, tokenId);
        }
        _;
    }

    /**
     * =============================================================
     * MAIN FUNCTIONS
     * =============================================================
     */

    /**
     * @notice Method for listing your NFT on the marketplace
     * @param nftAddress: Address of the NFT
     * @param tokenId: The Token ID of the NFT
     * @param price: Sale price of the listed NFT
     * @dev Technically, the contract could act as an NFT escrow. However this way people can still hold their NFTs while listed
     */

    // External listing function: going to be called by other accounts/projects
    function listItem(
        address nftAddress,
        uint256 tokenId,
        uint256 price
    ) external notListed(nftAddress, tokenId, msg.sender) isOwner(nftAddress, tokenId, msg.sender) {
        if (price <= 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        s_listings[nftAddress][tokenId] = Listing(price, msg.sender);
        emit ItemListed(msg.sender, nftAddress, tokenId, price);

        /**
         * 1) Send the NFT to the contract. Transfer -> Contract "hold" the NFT.
         * 2) Owners can still hold their NFT, and give the marketplace approval to sell the NFT for the lister.
         */

        /**
         * Pass nftAddress to IERC721 wrapper
         */
        IERC721 nft = IERC721(nftAddress);
        if (nft.getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
    }

    function buyItem(
        address nftAddress,
        uint256 tokenId
    ) external payable nonReentrant isListed(nftAddress, tokenId) {
        /**
         * Make sure enough money is sent
         */
        Listing memory listedItem = s_listings[nftAddress][tokenId];
        if (msg.value < listedItem.price) {
            revert NftMarketplace__PriceNotMet(nftAddress, tokenId, listedItem.price);
        }

        /**
         * We don't want to simply send ETH to the seller. Instead, we will allow them to safely withdraw the funds.
         */

        // When someone buys an item, update their proceeds
        s_proceeds[listedItem.seller] = s_proceeds[listedItem.seller] + msg.value;
        // The following mapping is removed
        delete (s_listings[nftAddress][tokenId]);
        // And then proceed with the transfer
        IERC721(nftAddress).safeTransferFrom(listedItem.seller, msg.sender, tokenId);
        // Verify transfer of the NFT
        emit ItemBought(msg.sender, nftAddress, tokenId, listedItem.price);
    }

    function cancelListing(
        address nftAddress,
        uint256 tokenId
    ) external isOwner(nftAddress, tokenId, msg.sender) isListed(nftAddress, tokenId) {
        delete (s_listings[nftAddress][tokenId]);
        emit ItemCanceled(msg.sender, nftAddress, tokenId);
    }

    function updateListing(
        address nftAddress,
        uint256 tokenId,
        uint256 newPrice
    ) external isListed(nftAddress, tokenId) isOwner(nftAddress, tokenId, msg.sender) {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(msg.sender, nftAddress, tokenId, newPrice);
    }

    // Collect all of our payments from our sold NFTs
    function withdrawPayments() external {
        uint256 proceeds = s_proceeds[msg.sender];
        if (proceeds <= 0) {
            revert NftMarketplace__NoProceeds();
        }
        // Reset proceeds to 0 before we send them
        s_proceeds[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: proceeds}("");
        if (!success) {
            revert NftMarketplace__TransferFailed();
        }
    }

    /**
     * =============================================================
     * GETTER FUNCTIONS
     * =============================================================
     */

    function getListing(
        address nftAddress,
        uint256 tokenId
    ) external view returns (Listing memory) {
        return s_listings[nftAddress][tokenId];
    }

    function getProceeds(address seller) external view returns (uint256) {
        return s_proceeds[seller];
    }
}

/*1. `listItem`: List NFTs on the marketplace
    2. `buyItem`: List NFTs on the marketplace
    3. `cancelItem`: List NFTs on the marketplace
    4. `updateListing`: List NFTs on the marketplace
    5. `withdrawProceeds`: List NFTs on the marketplace*/
