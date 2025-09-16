// SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.28;

contract FGOLibrary {
    enum Status {
        RESERVED,
        ACTIVE,
        DISABLED
    }

    enum Availability {
        DIGITAL_ONLY,
        PHYSICAL_ONLY,
        BOTH
    }

    struct CreateChildParams {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalEditions;
        Availability availability;
        bool isImmutable;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        bool digitalReferencesOpenToAll;
        bool physicalReferencesOpenToAll;
        bool standaloneAllowed;
        string childUri;
        address[] authorizedMarkets;
    }

    struct UpdateChildParams {
        uint256 childId;
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalEditions;
        bool makeImmutable;
        bool standaloneAllowed;
        string childUri;
        string updateReason;
        address[] authorizedMarkets;
    }

    struct ChildMetadata {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 version;
        uint256 maxPhysicalEditions;
        uint256 currentPhysicalEditions;
        uint256 uriVersion;
        uint256 usageCount;
        uint256 supplyCount;
        address supplier;
        Status status;
        Availability availability;
        bool isImmutable;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        bool digitalReferencesOpenToAll;
        bool physicalReferencesOpenToAll;
        bool standaloneAllowed;
        bool isTemplate;
        string uri;
        address[] authorizedMarkets;
        URIVersion[] uriHistory;
    }

    struct ChildReference {
        uint256 childId;
        uint256 amount;
        address childContract;
        string placementURI;
    }

    struct DemandEntry {
        uint256 childId;
        address childContract;
        uint256 cumulativeDemand;
    }

    struct URIVersion {
        uint256 version;
        uint256 timestamp;
        string uri;
        string updateReason;
    }

    struct ParentMetadata {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 totalPurchases;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        uint256 currentDigitalEditions;
        uint256 currentPhysicalEditions;
        address designer;
        uint8 printType;
        Availability availability;
        Status status;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        string uri;
        ChildReference[] childReferences;
        address[] authorizedMarkets;
        uint256[] tokenIds;
        FulfillmentWorkflow workflow;
    }

    enum CompositeStatus {
        PENDING,
        FULFILLED,
        REFUNDED
    }

    struct Currency {
        uint256 weiAmount;
        uint256 rate;
    }

    struct FulfillerProfile {
        uint256 version;
        uint256 basePrice;
        uint256 vigBasisPoints;
        address fulfillerAddress;
        bool isActive;
        string uri;
    }

    struct DesignerProfile {
        uint256 version;
        address designerAddress;
        bool isActive;
        string uri;
    }

    struct SupplierProfile {
        uint256 version;
        address supplierAddress;
        bool isActive;
        string uri;
    }

    struct SubPerformer {
        uint256 splitBasisPoints;
        address performer;
    }

    struct FulfillmentStep {
        address primaryPerformer;
        string instructions;
        SubPerformer[] subPerformers;
    }

    struct FulfillmentWorkflow {
        FulfillmentStep[] digitalSteps;
        FulfillmentStep[] physicalSteps;
    }

    struct CreateParentParams {
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        uint8 printType;
        Availability availability;
        bool digitalMarketsOpenToAll;
        bool physicalMarketsOpenToAll;
        string uri;
        ChildReference[] childReferences;
        address[] authorizedMarkets;
        FulfillmentWorkflow workflow;
    }

    struct UpdateParentParams {
        uint256 designId;
        uint256 digitalPrice;
        uint256 physicalPrice;
        uint256 maxDigitalEditions;
        uint256 maxPhysicalEditions;
        address[] authorizedMarkets;
    }

    struct MarketApprovalRequest {
        uint256 designId;
        uint256 timestamp;
        address market;
        bool isPending;
    }

    struct ParentApprovalRequest {
        uint256 childId;
        uint256 parentId;
        uint256 requestedAmount;
        uint256 timestamp;
        address parentContract;
        bool isPending;
    }

    struct ChildMarketApprovalRequest {
        uint256 childId;
        uint256 timestamp;
        address market;
        bool isPending;
    }

    struct TemplateApprovalRequest {
        uint256 childId;
        uint256 templateId;
        uint256 requestedAmount;
        uint256 timestamp;
        address templateContract;
        bool isPending;
    }

    struct PhysicalRights {
        uint256 guaranteedAmount;
        address purchaseMarket;
    }

    struct InfrastructureAddresses {
        address accessControl;
        address suppliers;
        address designers;
        address fulfillers;
        address deployer;
        address superAdmin;
        string uri;
        bool exists;
        bool isActive;
    }

    struct ChildContractData {
        uint256 childType;
        address childContract;
        address deployer;
        bool exists;
    }

    struct TemplateContractData {
        uint256 childType;
        address templateContract;
        address deployer;
        bool exists;
    }

    struct ParentContractData {
        address deployer;
        address parentContract;
        bool exists;
    }

    struct MarketContractData {
        address deployer;
        address marketContract;
        bool exists;
    }
}
