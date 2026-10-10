using System;
using System.Collections.Generic;

namespace DistributorPortal.Models
{
    public class LoginViewModel
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class DashboardViewModel
    {
        public string StaffName { get; set; }
        public string DistributorName { get; set; }
        public int TotalQuotations { get; set; }
        public int PendingQuotations { get; set; }
        public int ConfirmedToday { get; set; }
        public decimal RevenueToday { get; set; }
        public List<QuotationViewModel> RecentQuotations { get; set; }
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
        public string? ConfirmedBy { get; set; }
    }

    public class QuotationDetailViewModel
    {
        public int QuotationId { get; set; }
        public int OrderId { get; set; }
        public string DistributorName { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public DateTime QuotationDate { get; set; }
        public string Status { get; set; }
        public string DistributorOrderId { get; set; }
        public DateTime? ConfirmedDate { get; set; }
        public List<InventoryItemViewModel> InventoryItems { get; set; }
        public List<QuotationStatusViewModel> AllQuotations { get; set; }
    }

    public class InventoryItemViewModel
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int RequestedQuantity { get; set; }
        public int AvailableQuantity { get; set; }
        public decimal UnitPrice { get; set; }
        public bool InStock { get; set; }
    }

    public class QuotationStatusViewModel
    {
        public string DistributorName { get; set; }
        public string Status { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public string DistributorOrderId { get; set; }
    }
}