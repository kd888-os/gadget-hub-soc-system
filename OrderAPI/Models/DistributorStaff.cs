using System;
using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace OrderAPI.Models
{
    [Table("DistributorStaff")]
    public class DistributorStaff
    {
        [Key]
        public int StaffId { get; set; }

        [Required]
        [StringLength(100)]
        public string DistributorName { get; set; }

        [Required]
        [StringLength(100)]
        public string Username { get; set; }

        [Required]
        [StringLength(255)]
        public string Password { get; set; }

        [Required]
        [StringLength(200)]
        public string FullName { get; set; }

        [Required]
        [StringLength(255)]
        public string Email { get; set; }

        public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
    }
}