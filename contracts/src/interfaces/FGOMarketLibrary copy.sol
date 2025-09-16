// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.28;

contract FGOMarketLibrary {
    enum PaymentType {
        CHILD_PAYMENT,
        PARENT_PAYMENT,
        TEMPLATE_PAYMENT,
        FULFILLER_PAYMENT
    }

    enum OrderStatus {
        PAID,
        CANCELLED,
        REFUNDED,
        DISPUTED
    }

    struct PurchaseParams {
        uint256 parentId;
        uint256 parentAmount;
        uint256 childId;
        uint256 childAmount;
        uint256 templateId;
        uint256 templateAmount;
        address parentContract;
        address childContract;
        address templateContract;
        bool isPhysical;
        bytes fulfillmentData;
    }

    struct PaymentItem {
        uint256 amount;
        address recipient;
        PaymentType paymentType;
    }

    struct PaymentBreakdown {
        uint256 totalPayments;
        PaymentItem[] payments;
    }

    struct OrderReceipt {
        uint256 timestamp;
        uint256 orderId;
        address buyer;
        PurchaseParams params;
        PaymentBreakdown breakdown;
        OrderStatus status;
    }
    
    struct FulfillmentStatus {
        uint256 orderId;
        uint256 parentId;
        uint256 currentStep;
        uint256 createdAt;
        uint256 lastUpdated;
        address parentContract;
        StepCompletion[] steps;
    }
    
    struct StepCompletion {
        uint256 completedAt;
        address fulfiller;
        bool isCompleted;
        string notes;
    }
}
