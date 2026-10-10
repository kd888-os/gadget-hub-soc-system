using System;
using System.Collections.Generic;

namespace TechWorldPortal.Models
{
    public class LoginViewModel
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class QuotationRequestViewModel
    {
        public int QuotationId { get; set; }
        public int OrderId { get; set; }
        public string CustomerName { get; set; }
        public DateTime RequestDate { get; set; }
        public List<QuotationItemViewModel> Items { get; set; }
        public decimal TotalPrice { get; set; }
        public string Status { get; set; }
    }

    public class QuotationItemViewModel
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int RequestedQuantity { get; set; }
        public int AvailableQuantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public bool InStock { get; set; }
    }

    public class ConfirmQuotationViewModel
    {
        public int QuotationId { get; set; }
        public int OrderId { get; set; }
        public string Action { get; set; } // "Confirm" or "Reject"
        public string DistributorOrderId { get; set; }
        public DateTime? EstimatedDeliveryDate { get; set; }
        public string RejectionReason { get; set; }
    }

    public class DashboardViewModel
    {
        public int PendingQuotations { get; set; }
        public int ConfirmedToday { get; set; }
        public int RejectedToday { get; set; }
        public decimal TotalRevenueToday { get; set; }
        public List<QuotationRequestViewModel> RecentQuotations { get; set; }
    }
}