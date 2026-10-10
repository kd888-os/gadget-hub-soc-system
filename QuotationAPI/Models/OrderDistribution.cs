using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace QuotationAPI.Models
{
    [Table("OrderDistributions")]
    public class OrderDistribution
    {
        [Key]
        public int DistributionId { get; set; }

        [Required]
        public int OrderId { get; set; }

        [Required]
        [StringLength(100)]
        public string DistributorName { get; set; }

        [Required]
        public int ProductId { get; set; }

        [Required]
        [StringLength(200)]
        public string ProductName { get; set; }

        [Required]
        public int Quantity { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal TotalPrice { get; set; }

        [StringLength(50)]
        public string DistributorOrderId { get; set; }

        [StringLength(50)]
        public string Status { get; set; } = "Pending";

        public DateTime? EstimatedDeliveryDate { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}