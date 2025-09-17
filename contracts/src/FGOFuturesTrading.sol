// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesContract.sol";
import "./FGOFuturesEscrow.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesTrading is ERC1155, ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesContract public futuresContract;
    FGOFuturesEscrow public escrow;
    string public symbol;
    string public name;
    address public lpTreasury;
    address public protocolTreasury;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 private protocolFeeBPS;
    uint256 private lpFeeBPS;
    uint256 private orderCount;

    mapping(uint256 => uint256) private totalSupply;
    mapping(uint256 => bool) private tokenMinted;
    mapping(uint256 => uint256) private contractIdByToken;
    mapping(uint256 => FGOFuturesLibrary.SellOrder) private sellOrders;
    mapping(uint256 => mapping(uint256 => address)) private holderAtBlock;
    mapping(uint256 => string) private tokenURIs;

    event SellOrderCreated(
        uint256 indexed orderId,
        uint256 indexed tokenId,
        uint256 quantity,
        uint256 pricePerUnit,
        address seller
    );
    event SellOrderFilled(
        uint256 indexed orderId,
        uint256 quantity,
        uint256 totalPrice,
        address buyer
    );
    event SellOrderCancelled(uint256 indexed orderId, address seller);
    event FeesCollected(
        uint256 indexed orderId,
        uint256 protocolFee,
        uint256 lpFee
    );

    modifier onlyAdmin() {
        if (!accessControl.isAdmin(msg.sender)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    modifier onlyFuturesContract() {
        if (msg.sender != address(futuresContract)) {
            revert FGOFuturesErrors.Unauthorized();
        }
        _;
    }

    constructor(
        address _accessControl,
        address _futuresContract,
        address _escrow,
        address _lpTreasury,
        address _protocolTreasury,
        uint256 _protocolFeeBPS,
        uint256 _lpFeeBPS
    ) ERC1155("") {
        if (_lpTreasury == address(0)) revert FGOFuturesErrors.InvalidAmount();
        if (_protocolTreasury == address(0))
            revert FGOFuturesErrors.InvalidAmount();

        accessControl = FGOFuturesAccessControl(_accessControl);
        futuresContract = FGOFuturesContract(_futuresContract);
        escrow = FGOFuturesEscrow(_escrow);
        lpTreasury = _lpTreasury;
        protocolTreasury = _protocolTreasury;
        protocolFeeBPS = _protocolFeeBPS;
        lpFeeBPS = _lpFeeBPS;
        symbol = "FGOFT";
        name = "FGOFuturesTrading";
    }

    function createSellOrder(
        uint256 tokenId,
        uint256 quantity,
        uint256 pricePerUnit
    ) external nonReentrant returns (uint256 orderId) {
        return _createSellOrder(tokenId, quantity, pricePerUnit, msg.sender);
    }

    function createSellOrderFromContract(
        uint256 tokenId,
        uint256 quantity,
        uint256 pricePerUnit,
        address seller
    ) external onlyFuturesContract returns (uint256 orderId) {
        return _createSellOrder(tokenId, quantity, pricePerUnit, seller);
    }

    function _createSellOrder(
        uint256 tokenId,
        uint256 quantity,
        uint256 pricePerUnit,
        address seller
    ) internal returns (uint256 orderId) {
        if (!tokenMinted[tokenId]) revert FGOFuturesErrors.TokenNotMinted();
        if (balanceOf(seller, tokenId) < quantity)
            revert FGOFuturesErrors.InsufficientBalance();
        if (quantity == 0) revert FGOFuturesErrors.InvalidQuantity();
        if (pricePerUnit == 0) revert FGOFuturesErrors.InvalidPrice();

        orderId = orderCount++;

        sellOrders[orderId] = FGOFuturesLibrary.SellOrder({
            tokenId: tokenId,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            filled: 0,
            createdAt: block.timestamp,
            seller: seller,
            isActive: true
        });

        emit SellOrderCreated(
            orderId,
            tokenId,
            quantity,
            pricePerUnit,
            seller
        );
    }

    function buyFromOrder(
        uint256 orderId,
        uint256 quantityToBuy
    ) external nonReentrant {
        FGOFuturesLibrary.SellOrder storage order = sellOrders[orderId];

        if (!order.isActive) revert FGOFuturesErrors.OrderNotActive();
        if (quantityToBuy == 0) revert FGOFuturesErrors.InvalidQuantity();
        if (quantityToBuy > (order.quantity - order.filled))
            revert FGOFuturesErrors.ExceedsAvailable();

        uint256 contractId = contractIdByToken[order.tokenId];
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        if (fc.isSettled) revert FGOFuturesErrors.ContractSettled();

        uint256 totalPrice = order.pricePerUnit * quantityToBuy;
        uint256 protocolFee = (totalPrice * protocolFeeBPS) / BASIS_POINTS;
        uint256 lpFee = (totalPrice * lpFeeBPS) / BASIS_POINTS;
        uint256 sellerProceeds = totalPrice - protocolFee - lpFee;

        address monaToken = accessControl.monaToken();

        IERC20(monaToken).transferFrom(
            msg.sender,
            order.seller,
            sellerProceeds
        );
        IERC20(monaToken).transferFrom(
            msg.sender,
            protocolTreasury,
            protocolFee
        );
        IERC20(monaToken).transferFrom(msg.sender, lpTreasury, lpFee);

        _safeTransferFrom(
            order.seller,
            msg.sender,
            order.tokenId,
            quantityToBuy,
            ""
        );

        order.filled += quantityToBuy;
        if (order.filled == order.quantity) {
            order.isActive = false;
        }

        holderAtBlock[order.tokenId][block.number] = msg.sender;

        emit SellOrderFilled(orderId, quantityToBuy, totalPrice, msg.sender);
        emit FeesCollected(orderId, protocolFee, lpFee);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        FGOFuturesLibrary.SellOrder storage order = sellOrders[orderId];

        if (order.seller != msg.sender) revert FGOFuturesErrors.NotSeller();
        if (!order.isActive) revert FGOFuturesErrors.OrderNotActive();

        order.isActive = false;

        emit SellOrderCancelled(orderId, msg.sender);
    }

    function getSellOrder(
        uint256 orderId
    ) external view returns (FGOFuturesLibrary.SellOrder memory) {
        return sellOrders[orderId];
    }

    function getTotalSupply(uint256 tokenId) external view returns (uint256) {
        return totalSupply[tokenId];
    }

    function isTokenMinted(uint256 tokenId) external view returns (bool) {
        return tokenMinted[tokenId];
    }

    function getContractIdByToken(
        uint256 tokenId
    ) external view returns (uint256) {
        return contractIdByToken[tokenId];
    }

    function getHolderAtBlock(
        uint256 tokenId,
        uint256 blockNumber
    ) external view returns (address) {
        return holderAtBlock[tokenId][blockNumber];
    }

    function getOrderCount() public view returns (uint256) {
        return orderCount;
    }

    function getLpFee() public view returns (uint256) {
        return lpFeeBPS;
    }

    function getProtocolFee() public view returns (uint256) {
        return protocolFeeBPS;
    }

    function setLpTreasury(address _lpTreasury) external onlyAdmin {
        if (_lpTreasury == address(0)) revert FGOFuturesErrors.InvalidAmount();
        lpTreasury = _lpTreasury;
    }

    function setProtocolTreasury(address _protocolTreasury) external onlyAdmin {
        if (_protocolTreasury == address(0))
            revert FGOFuturesErrors.InvalidAmount();
        protocolTreasury = _protocolTreasury;
    }

    function setProtocolFeeBPS(uint256 _protocolFeeBPS) external onlyAdmin {
        if (_protocolFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();
        protocolFeeBPS = _protocolFeeBPS;
    }

    function setLpFeeBPS(uint256 _lpFeeBPS) external onlyAdmin {
        if (_lpFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();
        lpFeeBPS = _lpFeeBPS;
    }

    function mint(
        uint256 tokenId,
        uint256 amount,
        address account,
        string memory tokenUri
    ) external onlyFuturesContract {
        _mint(account, tokenId, amount, "");

        if (!tokenMinted[tokenId]) {
            tokenMinted[tokenId] = true;
            contractIdByToken[tokenId] = futuresContract.getContractByToken(
                tokenId
            );
            tokenURIs[tokenId] = tokenUri;
            emit URI(tokenUri, tokenId);
        }

        totalSupply[tokenId] += amount;
        holderAtBlock[tokenId][block.number] = account;
    }

    function burn(address account, uint256 tokenId, uint256 amount) external {
        if (msg.sender != address(escrow) && msg.sender != address(futuresContract))
            revert FGOFuturesErrors.Unauthorized();
        _burn(account, tokenId, amount);
        totalSupply[tokenId] -= amount;
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return tokenURIs[tokenId];
    }
}
