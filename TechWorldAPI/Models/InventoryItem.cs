using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TechWorldAPI.Models
{
    [Table("Inventory")]
    public class InventoryItem
    {
        [Key]
        public int InventoryId { get; set; }

        [Required]
        public int ProductId { get; set; }

        [Required]
        [StringLength(200)]
        public string ProductName { get; set; }

        [Required]
        [Column(TypeName = "decimal(18,2)")]
        public decimal UnitPrice { get; set; }

        [Required]
        public int StockQuantity { get; set; }

        public int ReorderLevel { get; set; } = 10;

        public DateTime LastUpdated { get; set; } = DateTime.UtcNow;
    }
}