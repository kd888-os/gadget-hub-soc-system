using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using GadgetCentralAPI.Data;
using GadgetCentralAPI.Models;

namespace GadgetCentralAPI.Controllers
{
    [ApiController]
    [Route("api/gadgetcentral")]
    public class GadgetCentralController : ControllerBase
    {
        private readonly GadgetCentralDbContext _context;

        public GadgetCentralController(GadgetCentralDbContext context)
        {
            _context = context;
        }

        [HttpPost("quote")]
        public async Task<IActionResult> GetQuote([FromBody] QuotationRequest request)
        {
            try
            {
                Console.WriteLine($"[GADGET CENTRAL] Processing quote request for Order {request.OrderId}...");

                if (request.Items == null || request.Items.Count == 0)
                {
                    Console.WriteLine("[GADGET CENTRAL] No items in request");
                    return BadRequest("No items in request");
                }

                var quotedItems = new List<QuotedItem>();
                decimal totalPrice = 0;
                int maxDeliveryDays = 2; // Base delivery time - FASTEST

                foreach (var item in request.Items)
                {
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

                            Console.WriteLine($"[GADGET CENTRAL] Product {item.ProductId}: {inventoryItem.ProductName}");
                            Console.WriteLine($"[GADGET CENTRAL]   Requested: {item.Quantity}, Available: {availableQty}, Price: Rs. {inventoryItem.UnitPrice:N2}/unit");
                        }
                        else
                        {
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
                            Console.WriteLine($"[GADGET CENTRAL] Product {item.ProductId}: OUT OF STOCK");
                        }
                    }
                    else
                    {
                        Console.WriteLine($"[GADGET CENTRAL] Warning: Product {item.ProductId} not in catalog");
                    }
                }

                var quote = new QuotationResponse
                {
                    DistributorName = "Gadget Central",
                    TotalPrice = Math.Round(totalPrice, 2),
                    DeliveryDays = maxDeliveryDays,
                    Items = quotedItems,
                    CanFulfillCompleteOrder = quotedItems.All(i => i.InStock)
                };

                Console.WriteLine($"[GADGET CENTRAL] ✓ Quote generated: Rs. {quote.TotalPrice:N2} (2-day delivery - FASTEST!)");
                Console.WriteLine($"[GADGET CENTRAL]   Can fulfill complete order: {quote.CanFulfillCompleteOrder}");

                return Ok(quote);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GADGET CENTRAL] Error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to generate quote", Details = ex.Message });
            }
        }

        [HttpPost("confirm")]
        public async Task<IActionResult> ConfirmOrder([FromBody] OrderConfirmationRequest request)
        {
            try
            {
                Console.WriteLine($"[GADGET CENTRAL] Confirming order for {request.Items.Count} items...");

                foreach (var item in request.Items)
                {
                    var inventoryItem = await _context.Inventory
                        .FirstOrDefaultAsync(i => i.ProductId == item.ProductId);

                    if (inventoryItem != null && inventoryItem.StockQuantity >= item.Quantity)
                    {
                        inventoryItem.StockQuantity -= item.Quantity;
                        inventoryItem.LastUpdated = DateTime.UtcNow;
                        Console.WriteLine($"[GADGET CENTRAL] Reduced stock for Product {item.ProductId}: {item.Quantity} units");
                    }
                }

                await _context.SaveChangesAsync();

                var confirmation = new OrderConfirmation
                {
                    DistributorOrderId = $"GC-{DateTime.Now:yyyyMMdd}-{new Random().Next(1000, 9999)}",
                    DistributorName = "Gadget Central",
                    Status = "Confirmed",
                    EstimatedDeliveryDate = DateTime.Now.AddDays(2),
                    Items = request.Items.Select(i => new ConfirmedItem
                    {
                        ProductId = i.ProductId,
                        Quantity = i.Quantity,
                        Status = "Confirmed"
                    }).ToList()
                };

                Console.WriteLine($"[GADGET CENTRAL] ✓ Order confirmed: {confirmation.DistributorOrderId}");

                return Ok(confirmation);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GADGET CENTRAL] Confirmation error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to confirm order" });
            }
        }
    }

    // DTOs
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
}