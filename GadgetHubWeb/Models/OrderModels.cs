using System.Collections.Generic;

namespace GadgetHubWeb.Models
{
    public class OrderRequest
    {
        public int CustomerId { get; set; }
        public string CustomerName { get; set; }
        public List<OrderItemRequest> Items { get; set; }
    }

    public class OrderItemRequest
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
    }

    public class OrderResponse
    {
        public bool Success { get; set; }
        public int OrderId { get; set; }
        public decimal TotalAmount { get; set; }
        public bool IsSplitOrder { get; set; }
        public string SelectedDistributor { get; set; }
        public int? DeliveryDays { get; set; }
        public string Message { get; set; }
        public List<DistributionDetail> Distributions { get; set; }
    }

    public class DistributionDetail
    {
        public string DistributorName { get; set; }
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public string DistributorOrderId { get; set; }
    }

    public class Product
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public decimal BasePrice { get; set; }
        public string Category { get; set; }

        public decimal Price => BasePrice;
    }

    public class OrderStatusViewModel
    {
        public int OrderId { get; set; }
        public string CustomerName { get; set; }
        public DateTime OrderDate { get; set; }
        public string Status { get; set; }
        public decimal TotalAmount { get; set; }
        public string SelectedDistributor { get; set; }
        public int? DeliveryDays { get; set; }
        public string DistributorOrderId { get; set; }
        public DateTime? ConfirmedDate { get; set; }
        public List<OrderItemSummary> Items { get; set; }
        public List<QuotationStatusSummary> QuotationSummaries { get; set; }
    }

    public class OrderItemSummary
    {
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
    }

    public class QuotationStatusSummary
    {
        public string DistributorName { get; set; }
        public string Status { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public string DistributorOrderId { get; set; }
    }

    public class CustomerOrderViewModel
    {
        public int OrderId { get; set; }
        public DateTime OrderDate { get; set; }
        public decimal TotalAmount { get; set; }
        public string Status { get; set; }
        public string SelectedDistributor { get; set; }
        public int? DeliveryDays { get; set; }
        public bool IsSplitOrder { get; set; }
        public List<OrderItemSummary> Items { get; set; }
    }
}