// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

import "./FGOLibrary.sol";
import "./FGOMarketLibrary.sol";

interface IFGOChild {
    function getChildMetadata(
        uint256 childId
    ) external view returns (FGOLibrary.ChildMetadata memory);

    function childExists(uint256 childId) external view returns (bool);

    function isChildActive(uint256 childId) external view returns (bool);

    function getIsPhysicalRightsHolder(
        uint256 childId,
        uint256 orderId,
        address to,
        address marketContract
    ) external view returns (bool);

    function transferPhysicalRights(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address to,
        address marketContract
    ) external;

    function approvesParent(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);

    function getStandaloneAllowed(uint256 childId) external view returns (bool);

    function mint(
        uint256 childId,
        uint256 amount,
        uint256 orderId,
        uint256 estimatedDeliveryDuration,
        address to,
        bool isPhysical,
        bool isStandalone,
        bool reserveRights,
        uint256 prepaidAvailable
    ) external;

    function getParentApprovedAmount(
        uint256 childId,
        uint256 parentId,
        address parentContract,
        bool isPhysical
    ) external view returns (uint256);

    function getTemplateApprovedAmount(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (uint256);

    function fulfillPhysicalTokens(
        uint256 childId,
        uint256 orderId,
        uint256 amount,
        address buyer,
        address market
    ) external;

    function canPurchase(
        uint256 childId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);

    function requestMarketApproval(uint256 childId) external;

    function requestParentApproval(
        uint256 childId,
        uint256 parentId,
        uint256 requestedAmount,
        bool isPhysical
    ) external;

    function requestTemplateApproval(
        uint256 childId,
        uint256 templateId,
        uint256 requestedAmount,
        bool isPhysical
    ) external;

    function approvesTemplate(
        uint256 childId,
        uint256 templateId,
        address templateContract,
        bool isPhysical
    ) external view returns (bool);

    function incrementChildUsage(
        uint256 childId,
        uint256 entityId,
        uint256 amount,
        uint256 maxPhysicalEditions,
        uint256 maxDigitalEditions,
        bool isTemplate
    ) external;

    function decrementChildUsage(uint256 childId, uint256 entityId) external;

    function getPhysicalRightsHolders(
        uint256 childId,
        uint256 orderId,
        address marketContract
    ) external view returns (address[] memory);

    function getPhysicalRights(
        uint256 childId,
        uint256 orderId,
        address buyer,
        address marketContract
    ) external view returns (FGOLibrary.PhysicalRights memory);

    function reserveSupplyForRequest(
        uint256 childId,
        bytes32 requestId,
        uint256 amount,
        bool isPhysical
    ) external;

    function consumeReservedSupply(
        uint256 childId,
        bytes32 requestId,
        bool isPhysical
    ) external;

    function approveParent(
        uint256 childId,
        uint256 parentId,
        uint256 approvedAmount,
        address parentContract,
        bool isPhysical
    ) external;

    function approveTemplate(
        uint256 childId,
        uint256 templateId,
        uint256 approvedAmount,
        address templateContract,
        bool isPhysical
    ) external;

    function releaseReservedSupply(uint256 childId, bytes32 requestId) external;
}

interface IFGOTemplate {
    function getTemplatePlacements(
        uint256 childI
    ) external view returns (FGOLibrary.ChildReference[] memory);

    function canPurchase(
        uint256 templateId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);
}

interface IFGOParent {
    function designExists(uint256 designId) external view returns (bool);

    function getDesignTemplate(
        uint256 designId
    ) external view returns (FGOLibrary.ParentMetadata memory);

    function isParentActive(uint256 designId) external view returns (bool);

    function approvesMarket(
        uint256 childId,
        address market,
        bool isPhysical
    ) external view returns (bool);

    function mint(
        uint256 parentId,
        uint256 amount,
        address to,
        bool isPhysical
    ) external returns (uint256[] memory);

    function canPurchase(
        uint256 designId,
        uint256 amount,
        bool isPhysical,
        address market
    ) external view returns (bool);

    function updateStatusFromSupply(uint256 designId) external;

    function updatePrepaidSupply(
        uint256 designId,
        address childContract,
        uint256 childId,
        uint256 perParentAmount,
        uint256 totalPrepaidAmount,
        string calldata placementURI
    ) external;

    function getPrepaidAvailable(
        uint256 designId,
        address childContract,
        uint256 childId
    ) external view returns (uint256);

    function updatePrepaidUsed(
        uint256 designId,
        address childContract,
        uint256 childId,
        uint256 amountUsed
    ) external;
}

interface IFGOFulfillers {
    function getFulfillerIdByAddress(
        address fulfiller
    ) external view returns (uint256);

    function getFulfillerProfile(
        uint256 fulfillerId
    ) external view returns (FGOLibrary.FulfillerProfile memory);
}

interface IFGOMarket {
    function fulfillment() external view returns (address);

    function updateMarketOrderStatus(
        uint256 orderId,
        FGOMarketLibrary.OrderStatus status
    ) external;

    function getOrderReceipt(
        uint256 orderId
    ) external view returns (FGOMarketLibrary.OrderReceipt memory);
}

interface IFGOFuturesCoordination {
    function getFuturesCredits(
        address childContract,
        uint256 childId,
        address designer
    ) external view returns (uint256);

    function consumeFuturesCredits(
        address childContract,
        uint256 childId,
        address consumer,
        uint256 amount
    ) external;

    function createFuturesPosition(
        address childContract,
        uint256 childId,
        uint256 amount,
        uint256 pricePerUnit,
        uint256 deadline
    ) external;
}

interface IFGOFactory {
    function isValidContract(address _contract) external view returns (bool);

    function isValidChild(address _contract) external view returns (bool);

    function isValidParent(address _contract) external view returns (bool);

    function isInfrastructureActive(
        bytes32 infraId
    ) external view returns (bool);
}
