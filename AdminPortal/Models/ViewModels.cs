using System;
using System.Collections.Generic;

namespace AdminPortal.Models
{
    public class LoginViewModel
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class DashboardViewModel
    {
        public string AdminName { get; set; }
        public int TotalOrders { get; set; }
        public decimal TotalRevenue { get; set; }
        public int TotalCustomers { get; set; }
        public int TotalProducts { get; set; }
        public int OrdersToday { get; set; }
        public decimal RevenueToday { get; set; }
        public List<OrderViewModel> RecentOrders { get; set; } = new();
        public List<QuotationViewModel> RecentQuotations { get; set; } = new();
    }

    public class OrderViewModel
    {
        public int OrderId { get; set; }
        public int CustomerId { get; set; }
        public string CustomerName { get; set; }
        public DateTime OrderDate { get; set; }
        public decimal TotalAmount { get; set; }
        public string? SelectedDistributor { get; set; }
        public int? DeliveryDays { get; set; }
        public bool IsSplitOrder { get; set; }
        public string? Status { get; set; }
        public List<OrderItemViewModel>? Items { get; set; }
    }

    public class OrderItemViewModel
    {
        public int OrderItemId { get; set; }
        public int ProductId { get; set; }
        public string? ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
    }

    public class QuotationViewModel
    {
        public int QuotationId { get; set; }
        public int OrderId { get; set; }
        public string DistributorName { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public bool? CanFulfillCompleteOrder { get; set; }
        public DateTime QuotationDate { get; set; }
        public string? Status { get; set; }
        public string? DistributorOrderId { get; set; }
        public DateTime? ConfirmedDate { get; set; }
    }
}