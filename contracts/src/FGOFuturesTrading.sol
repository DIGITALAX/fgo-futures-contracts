// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOFuturesErrors.sol";
import "./FGOFuturesLibrary.sol";
import "./FGOFuturesAccessControl.sol";
import "./FGOFuturesContract.sol";
import "./FGOFuturesEscrow.sol";
import "./FGOFuturesSettlement.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FGOFuturesTrading is ERC1155, ReentrancyGuard {
    FGOFuturesAccessControl public accessControl;
    FGOFuturesContract public futuresContract;
    FGOFuturesEscrow public escrow;
    FGOFuturesSettlement public settlementContract;
    string public symbol;
    string public name;
    address public lpTreasury;
    address public protocolTreasury;

    uint256 public constant BASIS_POINTS = 10000;
    uint256 private _protocolFeeBPS;
    uint256 private _lpFeeBPS;
    uint256 private _orderCount;

    mapping(uint256 => uint256) private _totalSupply;
    mapping(uint256 => bool) private _tokenMinted;
    mapping(uint256 => uint256) private _contractIdByToken;
    mapping(uint256 => uint256) private _initialSellOrderByTokenId;
    mapping(uint256 => FGOFuturesLibrary.SellOrder) private _sellOrders;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => mapping(uint256 => uint256)) private _reservedQuantity;

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
    event SellOrderQuantityUpdated(
        uint256 indexed orderId,
        uint256 indexed tokenId,
        uint256 additionalQuantity
    );
    event FeesCollected(
        uint256 indexed orderId,
        uint256 settlementFee,
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
        uint256 protocolFeeBPS,
        uint256 lpFeeBPS
    ) ERC1155("") {
        if (_lpTreasury == address(0)) revert FGOFuturesErrors.InvalidAmount();
        if (_protocolTreasury == address(0))
            revert FGOFuturesErrors.InvalidAmount();
        if (_accessControl == address(0))
            revert FGOFuturesErrors.InvalidAmount();
        if (_futuresContract == address(0))
            revert FGOFuturesErrors.InvalidAmount();
        if (_escrow == address(0)) revert FGOFuturesErrors.InvalidAmount();
        if (protocolFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();
        if (lpFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();

        accessControl = FGOFuturesAccessControl(_accessControl);
        futuresContract = FGOFuturesContract(_futuresContract);
        escrow = FGOFuturesEscrow(_escrow);
        lpTreasury = _lpTreasury;
        protocolTreasury = _protocolTreasury;
        _protocolFeeBPS = protocolFeeBPS;
        _lpFeeBPS = lpFeeBPS;
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
        if (!_tokenMinted[tokenId]) revert FGOFuturesErrors.TokenNotMinted();
        uint256 availableBalance = balanceOf(seller, tokenId) -
            _reservedQuantity[seller][tokenId];
        if (availableBalance < quantity)
            revert FGOFuturesErrors.InsufficientBalance();
        if (quantity == 0) revert FGOFuturesErrors.InvalidQuantity();
        if (pricePerUnit == 0) revert FGOFuturesErrors.InvalidPrice();
        _orderCount++;
        orderId = _orderCount;
        _reservedQuantity[seller][tokenId] += quantity;

        _sellOrders[orderId] = FGOFuturesLibrary.SellOrder({
            tokenId: tokenId,
            quantity: quantity,
            pricePerUnit: pricePerUnit,
            filled: 0,
            createdAt: block.timestamp,
            seller: seller,
            isActive: true
        });

        emit SellOrderCreated(orderId, tokenId, quantity, pricePerUnit, seller);
    }

    function buyFromOrder(
        uint256 orderId,
        uint256 quantityToBuy
    ) external nonReentrant {
        FGOFuturesLibrary.SellOrder storage order = _sellOrders[orderId];

        if (!order.isActive) revert FGOFuturesErrors.OrderNotActive();
        if (quantityToBuy == 0) revert FGOFuturesErrors.InvalidQuantity();
        if (quantityToBuy > (order.quantity - order.filled))
            revert FGOFuturesErrors.ExceedsAvailable();

        uint256 contractId = _contractIdByToken[order.tokenId];
        FGOFuturesLibrary.FuturesContract memory fc = futuresContract
            .getFuturesContract(contractId);
        if (!fc.isActive) revert FGOFuturesErrors.ContractNotActive();
        if (fc.isSettled) revert FGOFuturesErrors.ContractSettled();

        uint256 totalPrice = order.pricePerUnit * quantityToBuy;
        address monaToken = accessControl.monaToken();

        uint256 settlementFee = 0;
        uint256 initialOrderId = _initialSellOrderByTokenId[order.tokenId];
        if (orderId == initialOrderId && address(settlementContract) != address(0)) {
            settlementFee = (totalPrice * fc.settlementRewardBPS) / BASIS_POINTS;
            IERC20(monaToken).transferFrom(
                msg.sender,
                address(settlementContract),
                settlementFee
            );
            settlementContract.addToRewardPool(contractId, settlementFee);
        }

        uint256 remaining = totalPrice - settlementFee;
        uint256 protocolFee = (remaining * _protocolFeeBPS) / BASIS_POINTS;
        uint256 lpFee = (remaining * _lpFeeBPS) / BASIS_POINTS;
        uint256 sellerProceeds = remaining - protocolFee - lpFee;

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
        _reservedQuantity[order.seller][order.tokenId] -= quantityToBuy;

        emit SellOrderFilled(orderId, quantityToBuy, totalPrice, msg.sender);
        emit FeesCollected(orderId, settlementFee, protocolFee, lpFee);
    }

    function cancelOrder(uint256 orderId) external nonReentrant {
        FGOFuturesLibrary.SellOrder storage order = _sellOrders[orderId];

        if (order.seller != msg.sender) revert FGOFuturesErrors.NotSeller();
        if (!order.isActive) revert FGOFuturesErrors.OrderNotActive();

        uint256 initialOrderId = _initialSellOrderByTokenId[order.tokenId];
        if (orderId == initialOrderId) {
            revert FGOFuturesErrors.CannotCancelInitialFuturesOrder();
        }

        order.isActive = false;
        _reservedQuantity[order.seller][order.tokenId] -= (order.quantity -
            order.filled);

        emit SellOrderCancelled(orderId, msg.sender);
    }

    function setInitialSellOrderId(
        uint256 tokenId,
        uint256 orderId
    ) external onlyFuturesContract {
        _initialSellOrderByTokenId[tokenId] = orderId;
    }

    function updateSellOrderQuantity(
        uint256 tokenId,
        uint256 additionalQuantity
    ) external onlyFuturesContract {
        uint256 orderId = _initialSellOrderByTokenId[tokenId];
        if (orderId == 0) revert FGOFuturesErrors.InvalidAmount();

        FGOFuturesLibrary.SellOrder storage order = _sellOrders[orderId];
        order.quantity += additionalQuantity;
        _reservedQuantity[order.seller][tokenId] += additionalQuantity;

        emit SellOrderQuantityUpdated(orderId, tokenId, additionalQuantity);
    }

    function getSellOrder(
        uint256 orderId
    ) external view returns (FGOFuturesLibrary.SellOrder memory) {
        return _sellOrders[orderId];
    }

    function getTotalSupply(uint256 tokenId) external view returns (uint256) {
        return _totalSupply[tokenId];
    }

    function isTokenMinted(uint256 tokenId) external view returns (bool) {
        return _tokenMinted[tokenId];
    }

    function getContractIdByToken(
        uint256 tokenId
    ) external view returns (uint256) {
        return _contractIdByToken[tokenId];
    }

    function getOrderCount() public view returns (uint256) {
        return _orderCount;
    }

    function getLpFee() public view returns (uint256) {
        return _lpFeeBPS;
    }

    function getProtocolFee() public view returns (uint256) {
        return _protocolFeeBPS;
    }

    function getReservedQuantity(
        address seller,
        uint256 tokenId
    ) public view returns (uint256) {
        return _reservedQuantity[seller][tokenId];
    }

    function getInitialSellOrderId(
        uint256 tokenId
    ) public view returns (uint256) {
        return _initialSellOrderByTokenId[tokenId];
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

    function setProtocolFeeBPS(uint256 protocolFeeBPS) external onlyAdmin {
        if (protocolFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();
        _protocolFeeBPS = protocolFeeBPS;
    }

    function setLPFeeBPS(uint256 lpFeeBPS) external onlyAdmin {
        if (lpFeeBPS > 1000) revert FGOFuturesErrors.InvalidAmount();
        _lpFeeBPS = lpFeeBPS;
    }

    function setSettlementContract(address _settlementContract) external onlyAdmin {
        if (_settlementContract == address(0)) revert FGOFuturesErrors.InvalidAmount();
        settlementContract = FGOFuturesSettlement(_settlementContract);
    }

    function mint(
        uint256 tokenId,
        uint256 amount,
        address account,
        string memory tokenUri
    ) external onlyFuturesContract {
        _mint(account, tokenId, amount, "");

        if (!_tokenMinted[tokenId]) {
            _tokenMinted[tokenId] = true;
            _contractIdByToken[tokenId] = futuresContract.getContractByToken(
                tokenId
            );
            _tokenURIs[tokenId] = tokenUri;
            emit URI(tokenUri, tokenId);
        }

        _totalSupply[tokenId] += amount;
    }

    function burn(address account, uint256 tokenId, uint256 amount) external {
        if (
            msg.sender != address(escrow) &&
            msg.sender != address(futuresContract)
        ) revert FGOFuturesErrors.Unauthorized();
        _burn(account, tokenId, amount);
        _totalSupply[tokenId] -= amount;
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override {
        uint256 reserved = _reservedQuantity[from][id];
        uint256 available = balanceOf(from, id) - reserved;
        if (amount > available) revert FGOFuturesErrors.InsufficientBalance();
        super.safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 reserved = _reservedQuantity[from][ids[i]];
            uint256 available = balanceOf(from, ids[i]) - reserved;
            if (amounts[i] > available)
                revert FGOFuturesErrors.InsufficientBalance();
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return _tokenURIs[tokenId];
    }
}
