using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using OrderAPI.Data;
using OrderAPI.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace OrderAPI.Controllers
{
    [ApiController]
    [Route("api/distributor")]
    public class DistributorController : ControllerBase
    {
        private readonly GadgetHubDbContext _context;
        private readonly IHttpClientFactory _httpClientFactory;

        public DistributorController(GadgetHubDbContext context, IHttpClientFactory httpClientFactory)
        {
            _context = context;
            _httpClientFactory = httpClientFactory;
        }

        // ===================================================
        // POST /api/distributor/login
        // ===================================================
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] DistributorLoginRequest request)
        {
            Console.WriteLine($"[ORDER API] Distributor login attempt: '{request.Username}'");

            var staff = await _context.DistributorStaff
                .FirstOrDefaultAsync(s =>
                    s.Username == request.Username &&
                    s.Password == request.Password);

            if (staff == null)
            {
                Console.WriteLine($"[ORDER API] Login failed for: '{request.Username}'");
                return Unauthorized(new { Message = "Invalid username or password" });
            }

            Console.WriteLine($"[ORDER API] Login success: {staff.FullName} ({staff.DistributorName})");

            return Ok(new
            {
                StaffId = staff.StaffId,
                FullName = staff.FullName,
                DistributorName = staff.DistributorName,
                Email = staff.Email
            });
        }

        // ===================================================
        // GET /api/distributor/{distributorName}/quotations
        // ===================================================
        [HttpGet("{distributorName}/quotations")]
        public async Task<IActionResult> GetDistributorQuotations(string distributorName)
        {
            Console.WriteLine($"[ORDER API] Fetching quotations for: '{distributorName}'");

            var quotations = await _context.Quotations
                .Where(q => q.DistributorName == distributorName)
                .OrderByDescending(q => q.QuotationDate)
                .Take(50)
                .ToListAsync();

            // Fix null values from old rows and check if order was taken by another distributor
            foreach (var q in quotations)
            {
                q.Status ??= "Confirmed";
                q.DistributorOrderId ??= "";
                q.ConfirmedBy ??= "";
                q.CanFulfillCompleteOrder ??= true;

                // If this quotation is still "Pending" but order was confirmed by another distributor
                if (q.Status == "Pending")
                {
                    var orderConfirmedByOther = await _context.Quotations
                        .AnyAsync(other =>
                            other.OrderId == q.OrderId &&
                            other.Status == "Confirmed" &&
                            other.DistributorName != distributorName);

                    if (orderConfirmedByOther)
                    {
                        // Mark as "Order Taken" for display only - NOT saved to DB
                        q.Status = "Order Taken";
                        Console.WriteLine($"[ORDER API] Quotation #{q.QuotationId} - Order already taken by another distributor");
                    }
                }
            }

            Console.WriteLine($"[ORDER API] Found {quotations.Count} quotations for '{distributorName}'");
            return Ok(quotations);
        }

        // ===================================================
        // GET /api/distributor/{distributorName}/quotations/{quotationId}/details
        // ===================================================
        [HttpGet("{distributorName}/quotations/{quotationId}/details")]
        public async Task<IActionResult> GetQuotationDetails(string distributorName, int quotationId)
        {
            Console.WriteLine($"[ORDER API] Getting details for quotation #{quotationId} ({distributorName})");

            var quotation = await _context.Quotations
                .FirstOrDefaultAsync(q =>
                    q.QuotationId == quotationId &&
                    q.DistributorName == distributorName);

            if (quotation == null)
            {
                Console.WriteLine($"[ORDER API] Quotation #{quotationId} not found for {distributorName}");
                return NotFound(new { Message = "Quotation not found" });
            }

            // Fix nulls
            quotation.Status ??= "Confirmed";
            quotation.DistributorOrderId ??= "";
            quotation.ConfirmedBy ??= "";

            // Get order items
            var orderItems = await _context.OrderItems
                .Where(oi => oi.OrderId == quotation.OrderId)
                .ToListAsync();

            Console.WriteLine($"[ORDER API] Found {orderItems.Count} items for order #{quotation.OrderId}");

            // Get all quotations for this order (to show competitor status)
            var allQuotations = await _context.Quotations
                .Where(q => q.OrderId == quotation.OrderId)
                .ToListAsync();

            // Fix nulls in all quotations
            foreach (var q in allQuotations)
            {
                q.Status ??= "Confirmed";
                q.DistributorOrderId ??= "";
            }

            // Check if already confirmed by another distributor
            var alreadyConfirmedByOther = allQuotations
                .Any(q => q.Status == "Confirmed" && q.DistributorName != distributorName);

            if (alreadyConfirmedByOther && quotation.Status == "Pending")
            {
                quotation.Status = "Order Taken";
            }

            // Get inventory from the distributor's own API
            var inventoryPort = distributorName == "TechWorld" ? 5101 :
                               distributorName == "ElectroCom" ? 5102 : 5103;

            var distributorApiName = distributorName.ToLower().Replace(" ", "");
            var inventoryItems = new List<InventoryCheckResult>();

            try
            {
                var httpClient = _httpClientFactory.CreateClient();
                httpClient.Timeout = TimeSpan.FromSeconds(5);

                var inventoryRequest = new
                {
                    OrderId = quotation.OrderId,
                    Items = orderItems.Select(oi => new
                    {
                        ProductId = oi.ProductId,
                        Quantity = oi.Quantity
                    }).ToList()
                };

                Console.WriteLine($"[ORDER API] Calling: http://localhost:{inventoryPort}/api/{distributorApiName}/quote");

                var response = await httpClient.PostAsJsonAsync(
                    $"http://localhost:{inventoryPort}/api/{distributorApiName}/quote",
                    inventoryRequest);

                Console.WriteLine($"[ORDER API] Distributor API response: {response.StatusCode}");

                if (response.IsSuccessStatusCode)
                {
                    var quoteResult = await response.Content.ReadFromJsonAsync<QuoteResponse>();
                    if (quoteResult?.Items != null)
                    {
                        inventoryItems = quoteResult.Items.Select(i => new InventoryCheckResult
                        {
                            ProductId = i.ProductId,
                            ProductName = i.ProductName,
                            RequestedQuantity = i.RequestedQuantity,
                            AvailableQuantity = i.AvailableQuantity,
                            UnitPrice = i.UnitPrice,
                            InStock = i.InStock
                        }).ToList();

                        Console.WriteLine($"[ORDER API] Got {inventoryItems.Count} inventory items");
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ORDER API] Could not fetch live inventory: {ex.Message}");

                // Fall back to order items data
                inventoryItems = orderItems.Select(oi => new InventoryCheckResult
                {
                    ProductId = oi.ProductId,
                    ProductName = oi.ProductName ?? $"Product #{oi.ProductId}",
                    RequestedQuantity = oi.Quantity,
                    AvailableQuantity = oi.Quantity,
                    UnitPrice = oi.UnitPrice,
                    InStock = true
                }).ToList();
            }

            return Ok(new QuotationDetailResponse
            {
                QuotationId = quotation.QuotationId,
                OrderId = quotation.OrderId,
                DistributorName = quotation.DistributorName,
                TotalPrice = quotation.TotalPrice,
                DeliveryDays = quotation.DeliveryDays,
                QuotationDate = quotation.QuotationDate,
                Status = quotation.Status,
                DistributorOrderId = quotation.DistributorOrderId,
                ConfirmedDate = quotation.ConfirmedDate,
                InventoryItems = inventoryItems,
                AllQuotations = allQuotations.Select(q => new QuotationStatusSummary
                {
                    DistributorName = q.DistributorName,
                    Status = q.Status ?? "Pending",
                    TotalPrice = q.TotalPrice,
                    DeliveryDays = q.DeliveryDays,
                    DistributorOrderId = q.DistributorOrderId ?? ""
                }).ToList()
            });
        }

        // ===================================================
        // POST /api/distributor/quotations/confirm
        // ===================================================
        [HttpPost("quotations/confirm")]
        public async Task<IActionResult> ConfirmQuotation([FromBody] QuotationConfirmRequest request)
        {
            try
            {
                Console.WriteLine($"[ORDER API] Processing quotation #{request.QuotationId} → '{request.Status}'");

                var quotation = await _context.Quotations
                    .FirstOrDefaultAsync(q => q.QuotationId == request.QuotationId);

                if (quotation == null)
                {
                    Console.WriteLine($"[ORDER API] Quotation #{request.QuotationId} not found!");
                    return NotFound(new { Message = "Quotation not found" });
                }

                // Check if already confirmed by another distributor
                if (request.Status == "Confirmed")
                {
                    var alreadyConfirmed = await _context.Quotations
                        .AnyAsync(q => q.OrderId == quotation.OrderId &&
                                       q.Status == "Confirmed" &&
                                       q.QuotationId != request.QuotationId);

                    if (alreadyConfirmed)
                    {
                        Console.WriteLine($"[ORDER API] Order #{quotation.OrderId} already confirmed by another distributor!");
                        return BadRequest(new { Message = "This order has already been confirmed by another distributor." });
                    }
                }

                // Update quotation status
                quotation.Status = request.Status;
                quotation.ConfirmedDate = DateTime.UtcNow;
                quotation.ConfirmedBy = request.ConfirmedBy ?? "Staff";

                if (request.Status == "Confirmed")
                {
                    quotation.DistributorOrderId = request.DistributorOrderId;
                    Console.WriteLine($"[ORDER API] Distributor Order ID: {request.DistributorOrderId}");
                }

                // Update the order immediately when confirmed
                var order = await _context.Orders
                    .FirstOrDefaultAsync(o => o.OrderId == quotation.OrderId);

                if (order != null)
                {
                    if (request.Status == "Confirmed")
                    {
                        order.Status = "Confirmed";
                        order.SelectedDistributor = quotation.DistributorName;
                        order.TotalAmount = quotation.TotalPrice;
                        order.DeliveryDays = quotation.DeliveryDays;
                        Console.WriteLine($"[ORDER API] ✓ Order #{order.OrderId} → Confirmed by {quotation.DistributorName}");
                        Console.WriteLine($"[ORDER API]   Total: Rs. {quotation.TotalPrice:N2}, Delivery: {quotation.DeliveryDays} days");
                    }
                    else if (request.Status == "Rejected")
                    {
                        // Check if ALL quotations are now rejected
                        var allQuotations = await _context.Quotations
                            .Where(q => q.OrderId == quotation.OrderId)
                            .ToListAsync();

                        var rejectedCount = allQuotations.Count(q =>
                            q.Status == "Rejected" || q.QuotationId == request.QuotationId);

                        if (rejectedCount >= allQuotations.Count)
                        {
                            order.Status = "All Quotations Rejected";
                            Console.WriteLine($"[ORDER API] All quotations rejected for Order #{order.OrderId}");
                        }
                        else
                        {
                            Console.WriteLine($"[ORDER API] Quotation rejected. {allQuotations.Count - rejectedCount} still pending.");
                        }
                    }
                }

                await _context.SaveChangesAsync();

                Console.WriteLine($"[ORDER API] ✓ Saved - Quotation #{request.QuotationId} → '{request.Status}'");
                return Ok(new { Success = true, Message = "Quotation updated successfully" });
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ORDER API] Error confirming quotation: {ex.Message}");
                return StatusCode(500, new { Error = ex.Message });
            }
        }

        // ===================================================
        // GET /api/distributor/orders/{orderId}/status
        // ===================================================
        [HttpGet("orders/{orderId}/status")]
        public async Task<IActionResult> GetOrderStatus(int orderId)
        {
            Console.WriteLine($"[ORDER API] Fetching status for order #{orderId}");

            var order = await _context.Orders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.OrderId == orderId);

            if (order == null)
            {
                Console.WriteLine($"[ORDER API] Order #{orderId} not found");
                return NotFound(new { Message = "Order not found" });
            }

            var quotations = await _context.Quotations
                .Where(q => q.OrderId == orderId)
                .ToListAsync();

            // Fix nulls
            order.Status ??= "Pending";
            order.SelectedDistributor ??= "";
            foreach (var item in order.Items ?? new List<OrderItem>())
                item.ProductName ??= $"Product #{item.ProductId}";

            foreach (var q in quotations)
            {
                q.Status ??= "Confirmed";
                q.DistributorOrderId ??= "";
            }

            var confirmedQuotation = quotations.FirstOrDefault(q => q.Status == "Confirmed");

            Console.WriteLine($"[ORDER API] Order #{orderId} status: {order.Status}");
            Console.WriteLine($"[ORDER API] Confirmed by: {confirmedQuotation?.DistributorName ?? "None"}");

            return Ok(new OrderStatusResponse
            {
                OrderId = order.OrderId,
                CustomerName = order.CustomerName,
                OrderDate = order.OrderDate,
                Status = order.Status,
                TotalAmount = order.TotalAmount,
                SelectedDistributor = order.SelectedDistributor,
                DeliveryDays = order.DeliveryDays,
                DistributorOrderId = confirmedQuotation?.DistributorOrderId,
                ConfirmedDate = confirmedQuotation?.ConfirmedDate,
                Items = order.Items?.Select(i => new OrderItemSummary
                {
                    ProductName = i.ProductName ?? $"Product #{i.ProductId}",
                    Quantity = i.Quantity,
                    UnitPrice = i.UnitPrice,
                    TotalPrice = i.UnitPrice * i.Quantity
                }).ToList() ?? new List<OrderItemSummary>(),
                QuotationSummaries = quotations.Select(q => new QuotationStatusSummary
                {
                    DistributorName = q.DistributorName,
                    Status = q.Status ?? "Pending",
                    TotalPrice = q.TotalPrice,
                    DeliveryDays = q.DeliveryDays,
                    DistributorOrderId = q.DistributorOrderId ?? ""
                }).ToList()
            });
        }
    }

    // ===================================================
    // DTOs
    // ===================================================

    public class DistributorLoginRequest
    {
        public string Username { get; set; }
        public string Password { get; set; }
    }

    public class QuotationConfirmRequest
    {
        public int QuotationId { get; set; }
        public string DistributorName { get; set; }
        public string DistributorOrderId { get; set; }
        public DateTime? EstimatedDeliveryDate { get; set; }
        public string Status { get; set; }
        public string RejectionReason { get; set; }
        public string ConfirmedBy { get; set; }
    }

    public class QuotationDetailResponse
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
        public List<InventoryCheckResult> InventoryItems { get; set; }
        public List<QuotationStatusSummary> AllQuotations { get; set; }
    }

    public class InventoryCheckResult
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int RequestedQuantity { get; set; }
        public int AvailableQuantity { get; set; }
        public decimal UnitPrice { get; set; }
        public bool InStock { get; set; }
    }

    public class QuotationStatusSummary
    {
        public string DistributorName { get; set; }
        public string Status { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public string DistributorOrderId { get; set; }
    }

    public class QuoteResponse
    {
        public string DistributorName { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
        public List<QuoteItemResponse> Items { get; set; }
        public bool CanFulfillCompleteOrder { get; set; }
    }

    public class QuoteItemResponse
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int RequestedQuantity { get; set; }
        public int AvailableQuantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public bool InStock { get; set; }
    }

    public class OrderStatusResponse
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
}