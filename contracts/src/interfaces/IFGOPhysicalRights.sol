// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOLibrary.sol";
import "./FGOMarketLibrary.sol";

interface IFGOChild {
    function transferPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address to,
        address marketContract
    ) external;

    function getPhysicalRights(
        uint256 childId,
        uint256 orderId,
        address buyer,
        address marketContract
    ) external view returns (FGOLibrary.PhysicalRights memory);

    function getPhysicalRightsHolders(
        uint256 childId,
        uint256 orderId,
        address marketContract
    ) external view returns (address[] memory);

    function getIsPhysicalRightsHolder(
        uint256 childId,
        uint256 orderId,
        address to,
        address marketContract
    ) external view returns (bool);

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address buyer,
        address marketContract
    ) external;

    function getChildMetadata(
        uint256 childId
    ) external view returns (FGOLibrary.ChildMetadata memory);

    function childExists(uint256 childId) external view returns (bool);

    function isChildActive(uint256 childId) external view returns (bool);

    function canPurchase(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);
}

interface IFGOFulfillment {
    function getFulfillmentStatus(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.FulfillmentStatus memory);
}

interface IFGOMarket {
    function getOrderReceipt(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.OrderReceipt memory);

    function fulfillment() external view returns (address);
}
