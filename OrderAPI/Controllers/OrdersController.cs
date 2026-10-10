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
    [Route("api/[controller]")]
    public class OrdersController : ControllerBase
    {
        private readonly GadgetHubDbContext _context;
        private readonly HttpClient _httpClient;

        public OrdersController(GadgetHubDbContext context, IHttpClientFactory httpClientFactory)
        {
            _context = context;
            _httpClient = httpClientFactory.CreateClient();
        }

        /// <summary>
        /// Creates a new order with intelligent distributor selection
        /// </summary>
        [HttpPost]
        public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
        {
            try
            {
                Console.WriteLine($"[ORDER API] Received order from {request.CustomerName}");

                // Step 1: Create order object
                var order = new Order
                {
                    CustomerId = request.CustomerId,
                    CustomerName = request.CustomerName,
                    OrderDate = DateTime.Now,
                    Status = "Pending Confirmation",
                    Items = request.Items.Select(item => new OrderItem
                    {
                        ProductId = item.ProductId,
                        ProductName = item.ProductName,
                        Quantity = item.Quantity,
                        UnitPrice = item.UnitPrice
                    }).ToList()
                };

                // Step 2: Calculate initial total
                order.TotalAmount = order.Items.Sum(i => i.Quantity * i.UnitPrice);

                // Step 3: Save order to database
                _context.Orders.Add(order);
                await _context.SaveChangesAsync();

                Console.WriteLine($"[ORDER API] Order {order.OrderId} saved to database");

                // Step 4: Call Quotation API for intelligent distribution
                try
                {
                    Console.WriteLine("[ORDER API] Requesting quotations and order distribution...");

                    var quotationRequest = new
                    {
                        OrderId = order.OrderId,
                        Items = request.Items.Select(i => new { i.ProductId, i.Quantity }).ToList()
                    };

                    var response = await _httpClient.PostAsJsonAsync(
                        "http://localhost:5002/api/quotations/request",
                        quotationRequest
                    );

                    if (response.IsSuccessStatusCode)
                    {
                        var distributionResult = await response.Content.ReadFromJsonAsync<OrderDistributionResponse>();

                        // Step 5: Update order with final pricing
                        order.TotalAmount = distributionResult.TotalPrice;
                        order.IsSplitOrder = distributionResult.IsSplitOrder;
                        order.DeliveryDays = distributionResult.MaxDeliveryDays;
                        order.Status = "Awaiting Distributor Confirmation";

                        // If single distributor, set it
                        if (!distributionResult.IsSplitOrder && distributionResult.Distributions.Any())
                        {
                            order.SelectedDistributor = distributionResult.Distributions.First().DistributorName;
                        }
                        else if (distributionResult.IsSplitOrder)
                        {
                            var distributorNames = string.Join(", ",
                                distributionResult.Distributions
                                    .Select(d => d.DistributorName)
                                    .Distinct());
                            order.SelectedDistributor = $"Split: {distributorNames}";
                        }

                        await _context.SaveChangesAsync();

                        Console.WriteLine($"[ORDER API] Order updated - Total: Rs. {order.TotalAmount:N2}, Split: {order.IsSplitOrder}");

                        // Step 6: Confirm orders with each distributor
                        var confirmations = await ConfirmWithDistributors(order.OrderId, distributionResult.Distributions);

                        // Step 7: Return comprehensive response
                        return Ok(new
                        {
                            Success = true,
                            OrderId = order.OrderId,
                            TotalAmount = order.TotalAmount,
                            IsSplitOrder = order.IsSplitOrder,
                            SelectedDistributor = order.SelectedDistributor,
                            DeliveryDays = order.DeliveryDays,
                            Distributions = distributionResult.Distributions.Select(d => new
                            {
                                d.DistributorName,
                                d.ProductName,
                                d.Quantity,
                                d.UnitPrice,
                                d.TotalPrice,
                                d.DeliveryDays,
                                DistributorOrderId = confirmations.FirstOrDefault(c =>
                                    c.DistributorName == d.DistributorName)?.DistributorOrderId
                            }).ToList(),
                            Message = distributionResult.IsSplitOrder
                                ? $"Order placed successfully across {distributionResult.Distributions.Select(d => d.DistributorName).Distinct().Count()} distributors!"
                                : "Order placed successfully!"
                        });
                    }
                    else
                    {
                        Console.WriteLine("[ORDER API] Quotation service returned error");
                        // Fallback: order saved but without optimal distribution
                        return Ok(new
                        {
                            Success = true,
                            OrderId = order.OrderId,
                            TotalAmount = order.TotalAmount,
                            Message = "Order saved but distributor selection unavailable. Will be processed manually."
                        });
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[ORDER API] Quotation service unavailable: {ex.Message}");

                    // Graceful degradation - order still saved
                    return Ok(new
                    {
                        Success = true,
                        OrderId = order.OrderId,
                        TotalAmount = order.TotalAmount,
                        Message = "Order saved. Distributor selection will be processed shortly."
                    });
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ORDER API] Error: {ex.Message}");
                return StatusCode(500, new { Error = "Failed to create order", Details = ex.Message });
            }
        }

        /// <summary>
        /// Confirms order with each selected distributor and gets confirmation IDs
        /// </summary>
        private async Task<List<DistributorConfirmation>> ConfirmWithDistributors(
            int orderId,
            List<DistributionItem> distributions)
        {
            Console.WriteLine($"[ORDER API] Confirming order {orderId} with distributors...");

            var confirmations = new List<DistributorConfirmation>();

            // Group items by distributor
            var groupedByDistributor = distributions
                .GroupBy(d => d.DistributorName)
                .ToList();

            foreach (var group in groupedByDistributor)
            {
                try
                {
                    string distributorUrl = group.Key switch
                    {
                        "TechWorld" => "http://localhost:5101/api/techworld/confirm",
                        "ElectroCom" => "http://localhost:5102/api/electrocom/confirm",
                        "Gadget Central" => "http://localhost:5103/api/gadgetcentral/confirm",
                        _ => null
                    };

                    if (distributorUrl == null)
                    {
                        Console.WriteLine($"[ORDER API] Unknown distributor: {group.Key}");
                        continue;
                    }

                    var confirmRequest = new
                    {
                        OrderId = orderId,
                        Items = group.Select(d => new
                        {
                            d.ProductId,
                            d.Quantity
                        }).ToList()
                    };

                    Console.WriteLine($"[ORDER API] Sending confirmation to {group.Key}...");
                    var response = await _httpClient.PostAsJsonAsync(distributorUrl, confirmRequest);

                    if (response.IsSuccessStatusCode)
                    {
                        var confirmation = await response.Content.ReadFromJsonAsync<DistributorConfirmationResponse>();

                        confirmations.Add(new DistributorConfirmation
                        {
                            DistributorName = group.Key,
                            DistributorOrderId = confirmation.DistributorOrderId,
                            Status = confirmation.Status,
                            EstimatedDeliveryDate = confirmation.EstimatedDeliveryDate
                        });

                        Console.WriteLine($"[ORDER API] ✓ {group.Key} confirmed: {confirmation.DistributorOrderId}");
                    }
                    else
                    {
                        Console.WriteLine($"[ORDER API] Failed to confirm with {group.Key}");
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"[ORDER API] Error confirming with {group.Key}: {ex.Message}");
                }
            }

            return confirmations;
        }

        [HttpGet("customer/{customerId}")]
        public async Task<IActionResult> GetCustomerOrders(int customerId)
        {
            Console.WriteLine($"[ORDER API] Fetching orders for customer #{customerId}");

            var orders = await _context.Orders
                .Include(o => o.Items)
                .Where(o => o.CustomerId == customerId)
                .OrderByDescending(o => o.OrderDate)
                .ToListAsync();

            foreach (var o in orders)
            {
                o.Status ??= "Pending";
                o.SelectedDistributor ??= "";
                foreach (var item in o.Items ?? new List<OrderItem>())
                    item.ProductName ??= $"Product #{item.ProductId}";
            }

            Console.WriteLine($"[ORDER API] Found {orders.Count} orders");
            return Ok(orders);
        }

        /// <summary>
        /// Gets an order by ID with all details
        /// </summary>
        [HttpGet("{id}")]
        public async Task<IActionResult> GetOrder(int id)
        {
            var order = await _context.Orders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.OrderId == id);

            if (order == null)
                return NotFound();

            return Ok(order);
        }

        /// <summary>
        /// Gets all orders
        /// </summary>
        [HttpGet]
        public async Task<IActionResult> GetAllOrders()
        {
            var orders = await _context.Orders
                .Include(o => o.Items)
                .OrderByDescending(o => o.OrderDate)
                .ToListAsync();

            return Ok(orders);
        }

        
    }

    // DTOs
    public class CreateOrderRequest
    {
        public int CustomerId { get; set; }
        public string CustomerName { get; set; }
        public List<CreateOrderItem> Items { get; set; }
    }

    public class CreateOrderItem
    {
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
    }

    public class OrderDistributionResponse
    {
        public int OrderId { get; set; }
        public decimal TotalPrice { get; set; }
        public bool IsSplitOrder { get; set; }
        public List<DistributionItem> Distributions { get; set; }
        public int MaxDeliveryDays { get; set; }
        public string Message { get; set; }
    }

    public class DistributionItem
    {
        public string DistributorName { get; set; }
        public int ProductId { get; set; }
        public string ProductName { get; set; }
        public int Quantity { get; set; }
        public decimal UnitPrice { get; set; }
        public decimal TotalPrice { get; set; }
        public int DeliveryDays { get; set; }
    }

    public class DistributorConfirmation
    {
        public string DistributorName { get; set; }
        public string DistributorOrderId { get; set; }
        public string Status { get; set; }
        public DateTime EstimatedDeliveryDate { get; set; }
    }

    public class DistributorConfirmationResponse
    {
        public string DistributorOrderId { get; set; }
        public string DistributorName { get; set; }
        public string Status { get; set; }
        public DateTime EstimatedDeliveryDate { get; set; }
    }
}