using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QuotationAPI.Models
{
    [Table("Quotations")]
    public class Quotation
    {
        [Key]
        public int QuotationId { get; set; }

        [Required]
        public int OrderId { get; set; }

        [Required]
        [StringLength(100)]
        public string DistributorName { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalPrice { get; set; }

        [Required]
        public int DeliveryDays { get; set; }

        public bool CanFulfillCompleteOrder { get; set; }

        public DateTime QuotationDate { get; set; } = DateTime.UtcNow;

        // Confirmation fields
        [StringLength(50)]
        public string Status { get; set; } = "Pending";

        [StringLength(50)]
        public string DistributorOrderId { get; set; }

        public DateTime? ConfirmedDate { get; set; }

        [StringLength(200)]
        public string ConfirmedBy { get; set; }
    }
}