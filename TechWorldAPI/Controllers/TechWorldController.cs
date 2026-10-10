using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using TechWorldAPI.Data;
using TechWorldAPI.Models;

namespace TechWorldAPI.Controllers
{
    [ApiController]
    [Route("api/techworld")]
    public class TechWorldController : ControllerBase
    {
        private readonly TechWorldDbContext _context;

        public TechWorldController(TechWorldDbContext context)
        {
            _context = context;
        }

        /// <summary>
        /// Generate quotation for customer order
        /// </summary>
        [HttpPost("quote")]
        public async Task<IActionResult> GetQuote([FromBody] QuotationRequest request)
        {
            try
            {
                Console.WriteLine($"[TECHWORLD] Processing quote request for Order {request.OrderId}...");

                if (request.Items == null || request.Items.Count == 0)
                {
                    Console.WriteLine("[TECHWORLD] No items in request");
                    return BadRequest("No items in request");
                }

                var quotedItems = new List<QuotedItem>();
                decimal totalPrice = 0;
                int maxDeliveryDays = 3; // Base delivery time

                foreach (var item in request.Items)
                {
                    // Check inventory for this product
                    var inventoryItem = await _context.Inventory
                        .FirstOrDefaultAsync(i => i.ProductId == item.ProductId);

                    if (inventoryItem != null)
                    {
                        int availableQty = Math.Min(item.Quantity, inventoryItem.StockQuantity);

                        if (availableQty > 0)
                        {
                            decimal itemTotal = inventoryItem.UnitPrice * availableQty;
                            totalPrice += itemTotal;

                            quotedItems.Add(new QuotedItem
                            {
                                ProductId = item.ProductId,
                                ProductName = inventoryItem.ProductName,
                                RequestedQuantity = item.Quantity,
                                AvailableQuantity = availableQty,
                                UnitPrice = inventoryItem.UnitPrice,
                                TotalPrice = itemTotal,
                                InStock = inventoryItem.StockQuantity >= item.Quantity
                            });

                            Console.WriteLine($"[TECHWORLD] Product {item.ProductId}: {inventoryItem.ProductName}");
                            Console.WriteLine($"[TECHWORLD]   Requested: {item.Quantity}, Available: {availableQty}, Price: Rs. {inventoryItem.UnitPrice:N2}/unit");
                        }
                        else
                        {
                            // Out of stock
                            quotedItems.Add(new QuotedItem
                            {
                                ProductId = item.ProductId,
                                ProductName = inventoryItem.ProductName,
                                RequestedQuantity = item.Quantity,
                                AvailableQuantity = 0,
                                UnitPrice = inventoryItem.UnitPrice,
                                TotalPrice = 0,
                                InStock = false
                            });
                            Console.WriteLine($"[TECHWORLD] Product {item.ProductId}: OUT OF STOCK");
                        }
                    }
                    else
                    {
                        Console.WriteLine($"[TECHWORLD] Warning: Product {item.ProductId} not in catalog");
                    }
                }

                var quote = new QuotationResponse
                {
                    DistributorName = "TechWorld",
                    TotalPrice = Math.Round(totalPrice, 2),
                    DeliveryDays = maxDeliveryDays,
                    Items = quotedItems,
                    CanFulfillCompleteOrder = quotedItems.All(i => i.InStock)
                };

                Console.WriteLine($"[TECHWORLD] ✓ Quote generated: Rs. {quote.TotalPrice:N2} (3-day delivery)");
                Console.WriteLine($"[TECHWORLD]   Can fulfill complete order: {quote.CanFulfillCompleteOrder}");

                return Ok(quote);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TECHWORLD] Error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to generate quote", Details = ex.Message });
            }
        }

        /// <summary>
        /// Confirm order and reduce inventory
        /// </summary>
        [HttpPost("confirm")]
        public async Task<IActionResult> ConfirmOrder([FromBody] OrderConfirmationRequest request)
        {
            try
            {
                Console.WriteLine($"[TECHWORLD] Confirming order for {request.Items.Count} items...");

                // Update inventory (reduce stock)
                foreach (var item in request.Items)
                {
                    var inventoryItem = await _context.Inventory
                        .FirstOrDefaultAsync(i => i.ProductId == item.ProductId);

                    if (inventoryItem != null && inventoryItem.StockQuantity >= item.Quantity)
                    {
                        inventoryItem.StockQuantity -= item.Quantity;
                        inventoryItem.LastUpdated = DateTime.UtcNow;
                        Console.WriteLine($"[TECHWORLD] Reduced stock for Product {item.ProductId}: {item.Quantity} units");
                    }
                }

                await _context.SaveChangesAsync();

                // Generate confirmation
                var confirmation = new OrderConfirmation
                {
                    DistributorOrderId = $"TW-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
                    DistributorName = "TechWorld",
                    Status = "Confirmed",
                    EstimatedDeliveryDate = DateTime.Now.AddDays(3),
                    Items = request.Items.Select(i => new ConfirmedItem
                    {
                        ProductId = i.ProductId,
                        Quantity = i.Quantity,
                        Status = "Confirmed"
                    }).ToList()
                };

                Console.WriteLine($"[TECHWORLD] ✓ Order confirmed: {confirmation.DistributorOrderId}");

                return Ok(confirmation);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TECHWORLD] Confirmation error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to confirm order" });
            }
        }

        /// <summary>
        /// Get pending quotations for staff portal
        /// </summary>
        [HttpGet("quotations/pending")]
        public async Task<IActionResult> GetPendingQuotations()
        {
            try
            {
                Console.WriteLine("[TECHWORLD] Fetching pending quotations...");

                // In a real system, this would fetch from a quotations table
                // For now, return empty list as quotations are auto-generated
                var pending = new List<object>();

                return Ok(pending);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TECHWORLD] Error fetching pending: {ex.Message}");
                return StatusCode(500);
            }
        }

        /// <summary>
        /// Get quotation details by ID
        /// </summary>
        [HttpGet("quotations/{id}")]
        public async Task<IActionResult> GetQuotationDetails(int id)
        {
            try
            {
                Console.WriteLine($"[TECHWORLD] Fetching quotation {id}...");

                // Fetch quotation details from database
                // For now, return sample data
                return Ok(new { QuotationId = id, Status = "Pending" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TECHWORLD] Error: {ex.Message}");
                return NotFound();
            }
        }

        /// <summary>
        /// Staff confirms or rejects a quotation
        /// </summary>
        [HttpPost("quotations/{id}/confirm")]
        public async Task<IActionResult> ConfirmQuotation(int id, [FromBody] QuotationConfirmationRequest request)
        {
            try
            {
                Console.WriteLine($"[TECHWORLD] Quotation {id} {request.Action}: {request.DistributorOrderId}");

                // Update quotation status in database
                // Send confirmation back to QuotationAPI

                return Ok(new { Success = true, Message = "Quotation processed" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[TECHWORLD] Error: {ex.Message}");
                return StatusCode(500);
            }
        }
    }

    // ===== DTOs =====

    public class QuotationRequest
    {
        public int OrderId { get; set; }
        public List<QuotationItem> Items { get; set; }
    }

    public class QuotationItem
    {
        public int ProductId { get; set; }
        public int Quantity { get; set; }
    }

    public class QuotationResponse
    {
        public string DistributorName { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public List<QuotedItem> Items { get; set; }
        public bool CanFulfillCompleteOrder { get; set; }
    }

    public class QuotedItem
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int RequestedQuantity { get; set; }
        public int AvailableQuantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public bool InStock { get; set; }
    }

    public class OrderConfirmationRequest
    {
        public int OrderId { get; set; }
        public List<OrderConfirmationItem> Items { get; set; }
    }

    public class OrderConfirmationItem
    {
        public int ProductId { get; set; }
        public int Quantity { get; set; }
    }

    public class OrderConfirmation
    {
        public string DistributorOrderId { get; set; }
        public string DistributorName { get; set; }
        public string Status { get; set; }
        public DateTime EstimatedDeliveryDate { get; set; }
        public List<ConfirmedItem> Items { get; set; }
    }

    public class ConfirmedItem
    {
        public int ProductId { get; set; }
        public int Quantity { get; set; }
        public string Status { get; set; }
    }

    public class QuotationConfirmationRequest
    {
        public string Action { get; set; } // "Confirm" or "Reject"
        public string DistributorOrderId { get; set; }
        public DateTime? EstimatedDeliveryDate { get; set; }
        public string RejectionReason { get; set; }
    }
}